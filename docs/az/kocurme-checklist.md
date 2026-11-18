[English](../migration-checklist.md) | **Azərbaycanca**

# Hər servis üçün köçürmə checklist-i

Bunu hər servisin merge request təsvirinə kopyala.

## Aşkarlama (VM-də)
- [ ] `scripts/vm-discovery.sh` işə salınıb və hesabat saxlanılıb
- [ ] Java versiyası, işləmə növü (Spring Boot jar / Tomcat WAR), port, aktiv profil
- [ ] Secret saxlayan konfiq faylları siyahıya alınıb (dəyərlər **kopyalanmayıb**)
- [ ] `/etc/hosts`-dakı standart olmayan sətirlər və onlardan hansılarını kodun həqiqətən istifadə etdiyi
- [ ] Cron job-lar, `@Scheduled` metodlar və startup job-ları
- [ ] Çıxan qoşulmalar (baza, Redis, tərəfdaş API-ləri, SMTP): pod şəbəkəsindən əlçatandırmı?
- [ ] Mount olunmuş fayl sistemləri və tətbiqin oxuduğu/yazdığı lokal fayllar

## Build
- [ ] `.gitlab-ci.yml` ortaq şablonları qoşur; build internetsiz runner-də işləyir
- [ ] Base image-lər sabitlənib və Nexus üzərindən çəkilir
- [ ] `finalName` təyin olunub; image daxili registry-yə push olunub

## Deploy
- [ ] Secret-lər Vault-da `apps/<servis>` yolundadır; konfiqdə placeholder-lər var
- [ ] Values faylı: image, `containerPort`, probe-lar (yalnız yoxlanmış path-lər), lazımdırsa `hostAliases`
- [ ] Ingress host = müştərilərin artıq istifadə etdiyi ad
- [ ] Servisin job-ları varsa `replicas: 1` + `Recreate`
- [ ] Argo CD Application sync olunub və sağlamdır

## Keçid
- [ ] Ingress controller-ə `curl -H 'Host: <müştəri-adı>'`: health + bir real endpoint
- [ ] VM-dəki tətbiq dayandırılıb (job-ları varsa), pod-da scheduler aktivdir
- [ ] HAProxy backend-i keçirilib; konfiq `haproxy -c` ilə yoxlanılıb; reload edilib
- [ ] Eyni curl HAProxy vasitəsilə; loglarda xəta yoxlanılıb
- [ ] VM söndürülənə qədər geri qaytarma sətri HAProxy-də şərh kimi saxlanılır
