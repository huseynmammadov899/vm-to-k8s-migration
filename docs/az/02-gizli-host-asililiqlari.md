[English](../02-hidden-host-dependencies.md) | **Azərbaycanca**

# 2. Gizli `/etc/hosts` asılılıqları

## Əlamət

Pod işə düşür və health check yaşıldır, amma ilk real sorğu xəta verir:

```
java.net.UnknownHostException: legacy-db.corp.example
```

Eyni host adı köhnə VM-də problemsiz açılır.

## Kök səbəb

İllər əvvəl kimsə VM-in `/etc/hosts` faylına sətirlər əlavə edib:

```
10.0.20.15   legacy-db.corp.example
10.0.30.7    partner-gateway
```

Bu adlar heç vaxt DNS-də olmayıb. Tətbiq onlardan asılı idi, amma bu heç yerdə sənədləşdirilməmişdi.
Pod-un `/etc/hosts` faylını isə kubelet yaradır, ona görə həmin sətirlər orada sadəcə yoxdur.

## Həll

**Qısa müddətə: Deployment-də `hostAliases`.** Bax: [`examples/k8s/deployment.yaml`](../../examples/k8s/deployment.yaml):

```yaml
hostAliases:
  - ip: "10.0.20.15"
    hostnames: ["legacy-db.corp.example"]
```

**Uzun müddətə: real DNS qeydləri yarat** və `hostAliases`-i sil. Manifest-lərə yazılmış IP-lər
növbəti dəfə server köçəndə səssizcə sınır.

## Hansı sətirləri köçürəcəyimi necə seçdim

Uzun illər işləyən VM-in `/etc/hosts` faylında onlarla sətir ola bilər. Hamısını kopyalamaq köhnə
qarışıqlığı Kubernetes-ə daşımaq deməkdir.

1. Standart olmayan sətirləri topla (discovery skripti bunu edir).
2. Hər host adını tətbiqin kodunda və konfiqində `grep -r` ilə axtar. Yalnız tətbiqin **həqiqətən istifadə etdiyi** adları saxla.
3. Hər adın cluster DNS-i ilə artıq açılıb-açılmadığını yoxla:
   ```bash
   kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup legacy-db.corp.example
   ```
4. Yalnız istifadə olunan **və** açılmayan adları əlavə et.

## Daha erkən necə tutmaq

Eyni nümunəyə başqa yerlərdə də diqqət et: `/etc/resolv.conf`-dakı search domenləri
(`partner-gateway` kimi qısa adlar VM-də `search corp.example` sayəsində açılır) və
`/etc/fstab`-dakı NFS mount-ları.
