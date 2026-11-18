**English** | [Azərbaycanca](az/kocurme-checklist.md)

# Per-service migration checklist

Copy this into the merge request description for each service.

## Discovery (on the VM)
- [ ] Ran `scripts/vm-discovery.sh` and saved the report
- [ ] Java version, runtime type (Spring Boot jar / Tomcat WAR), listening port, active profile
- [ ] Config files containing secrets listed (values **not** copied)
- [ ] Non-default `/etc/hosts` entries, plus which of them the code actually uses
- [ ] Cron jobs, `@Scheduled` methods and startup jobs
- [ ] Outbound connections (DB, Redis, partner APIs, SMTP), and are they reachable from pod network?
- [ ] Mounted file systems / local files the app reads or writes

## Build
- [ ] `.gitlab-ci.yml` includes the shared templates; build works on an offline runner
- [ ] Base images pinned and pulled through Nexus
- [ ] `finalName` set; image pushed to the internal registry

## Deploy
- [ ] Secrets in Vault at `apps/<service>`; placeholders in config
- [ ] Values file: image, `containerPort`, probes (verified paths only), `hostAliases` if needed
- [ ] Ingress host = the name clients already use
- [ ] `replicas: 1` + `Recreate` if the service has jobs
- [ ] Argo CD Application synced and healthy

## Cutover
- [ ] `curl -H 'Host: <client-name>'` against the ingress controller: health + one real endpoint
- [ ] VM app stopped (if it has jobs), scheduler enabled in pod
- [ ] HAProxy backend switched; config validated with `haproxy -c`; reloaded
- [ ] Same curl through HAProxy; logs checked for errors
- [ ] Rollback line kept commented in HAProxy until the VM is decommissioned
