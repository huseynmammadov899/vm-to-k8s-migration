#!/usr/bin/env bash
# vm-discovery.sh: read-only inventory of a legacy VM before migrating its apps to Kubernetes.
#
# It never prints secret VALUES. For config files it only reports which keys look sensitive.
# Usage: sudo ./vm-discovery.sh [output-dir]    (default: ./discovery-<hostname>)

set -uo pipefail

OUT="${1:-./discovery-$(hostname -s)}"
mkdir -p "$OUT"
REPORT="$OUT/report.md"
SEARCH_ROOTS=(/opt /srv /export /home /usr/local /var/lib)

section() { printf '\n## %s\n\n```\n' "$1" >>"$REPORT"; }
endsec()  { printf '```\n' >>"$REPORT"; }
run()     { "$@" >>"$REPORT" 2>&1 || true; }

[[ $EUID -ne 0 ]] && echo "warning: not root, some results will be incomplete" >&2

{
  echo "# Discovery report: $(hostname -f 2>/dev/null || hostname)"
  echo
  echo "Generated: $(date -Iseconds)"
} >"$REPORT"

section "OS and resources"
run cat /etc/os-release
run uname -r
run nproc
run free -h
run df -hT -x tmpfs -x devtmpfs
endsec

section "Java processes (full command line)"
run bash -c "ps -eo pid,user,etime,args | grep -E '[j]ava ' | sed -E 's/(-D[^ =]*(pass|secret|token)[^ =]*=)[^ ]*/\1*****/Ig'"
endsec

section "Java versions found"
for j in $(command -v java 2>/dev/null) /usr/lib/jvm/*/bin/java /opt/*/bin/java; do
  [[ -x "$j" ]] && { echo "$j:" >>"$REPORT"; "$j" -version >>"$REPORT" 2>&1; }
done
endsec

section "Listening ports"
run ss -ltnp
endsec

section "Established outbound connections (remote endpoints the apps depend on)"
run bash -c "ss -tnp state established | awk 'NR>1 {print \$4, \$5}' | sort | uniq -c | sort -rn | head -50"
endsec

section "Tomcat installations and deployed apps"
for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  find "$root" -maxdepth 6 -name catalina.sh -path '*/bin/*' 2>/dev/null | while read -r c; do
    base="${c%/bin/catalina.sh}"
    echo "== $base" >>"$REPORT"
    grep -oE 'port="[0-9]+"' "$base/conf/server.xml" 2>/dev/null | sort -u >>"$REPORT"
    ls -1 "$base/webapps" 2>/dev/null >>"$REPORT"
  done
done
endsec

section "Spring Boot jars"
for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] && find "$root" -maxdepth 6 -name '*.jar' -size +10M -not -path '*/lib/*' 2>/dev/null >>"$REPORT"
done
endsec

section "Non-default /etc/hosts entries (see docs/02)"
run bash -c "grep -vE '^\s*(#|$)|localhost|ip6-' /etc/hosts"
endsec

section "DNS search domains"
run grep -E '^(search|domain|nameserver)' /etc/resolv.conf
endsec

section "Scheduled jobs (see docs/03)"
run bash -c "for u in \$(cut -d: -f1 /etc/passwd); do c=\$(crontab -l -u \"\$u\" 2>/dev/null | grep -vE '^\s*(#|$)'); [[ -n \"\$c\" ]] && echo \"[\$u]\" && echo \"\$c\"; done"
run bash -c "grep -vhE '^\s*(#|$)' /etc/cron.d/* 2>/dev/null"
run systemctl list-timers --all --no-pager
endsec

section "Custom systemd services"
run bash -c "ls -1 /etc/systemd/system/*.service 2>/dev/null"
endsec

section "Network mounts"
run bash -c "grep -E 'nfs|cifs' /etc/fstab; mount | grep -E 'nfs|cifs'"
endsec

section "Config files with sensitive keys (values NOT shown, see docs/01)"
for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  find "$root" -maxdepth 7 -type f \( -name '*.properties' -o -name '*.yml' -o -name '*.yaml' \
       -o -name 'context.xml' -o -name '*.env' \) -size -1M 2>/dev/null |
  while read -r f; do
    keys=$(grep -oiE '^[[:space:]]*[A-Za-z0-9_.-]*(password|passwd|secret|token|apikey|api-key)[A-Za-z0-9_.-]*' "$f" 2>/dev/null |
           tr -d ' ' | sort -u | paste -sd, -)
    [[ -n "$keys" ]] && echo "$f: $keys" >>"$REPORT"
  done
done
endsec

section "Keystores and certificates"
for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] && find "$root" -maxdepth 7 -type f \( -name '*.jks' -o -name '*.p12' -o -name '*.pfx' \) 2>/dev/null >>"$REPORT"
done
endsec

chmod 600 "$REPORT"
echo "Report written to $REPORT"
