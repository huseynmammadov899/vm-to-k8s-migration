[English](../03-duplicate-scheduled-jobs.md) | **Azərbaycanca**

# 3. Scheduled job-lar iki dəfə işlədi

## Əlamət

Test zamanı yeni pod sağlam idi, HAProxy isə hələ VM-ə yönəlirdi. Bu, təhlükəsiz paralel işləmə
olmalı idi. Amma bazada **təkrarlanan sətirlər** yarandı, bəzi bildirişlər iki dəfə göndərildi.

## Kök səbəb

Tətbiqdə `@Scheduled` metodlar (bir halda isə startup job-u) var idi. Onlar taymerlə bazadan oxuyub
bazaya yazırdı. Bu job-lar gələn trafikdən asılı deyil. Pod işə düşən kimi VM-in gördüyü işi
eynilə görməyə başladı.

Load balancer routing-i HTTP trafikini qoruyur, **arxa fon job-larını yox**.

## Həll

**Köçürmədən əvvəl: özü-özünə işə düşən bütün job-ları tap.**

```bash
grep -rnE "@Scheduled|@EventListener\(ApplicationReadyEvent|CommandLineRunner|ApplicationRunner|Quartz" src/
crontab -l; ls /etc/cron.d/        # VM-də: tətbiqi çağıran OS səviyyəli job-lar
```

**Keçid zamanı: dəqiq bir yazıcı saxla.**

```yaml
spec:
  replicas: 1
  strategy:
    type: Recreate        # rollout zamanı belə eyni anda iki pod olmur
```

Job-u olan servislər üçün keçid ardıcıllığı:

1. Kubernetes-ə scheduler **söndürülmüş** halda deploy et (`SCHEDULER_ENABLED=false`, bunu
   `@ConditionalOnProperty` oxuyur).
2. HTTP endpoint-ləri ingress vasitəsilə yoxla.
3. Tətbiqi VM-də dayandır.
4. Pod-da scheduler-i aktiv et.
5. HAProxy-ni keçir.

**Uzun müddətə:** servisə birdən çox replica lazımdırsa, [ShedLock](https://github.com/lukas-krecan/ShedLock)
kimi paylanmış kilid istifadə et. Belə olanda hər job-u yalnız bir instance işlədir. Alternativ
olaraq job-u Kubernetes `CronJob`-a köçür.

## Dərs

Scheduler-i olan tətbiqi "sadəcə test üçün" lokalda ortaq bazaya qoşub işə salma. Bu, eyni xətanın kiçik miqyaslı versiyasıdır.
