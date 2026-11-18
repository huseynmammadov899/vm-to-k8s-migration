[English](../04-host-header-cutover.md) | **Azərbaycanca**

# 4. Keçid zamanı Host header və ingress routing

## Əlamət

Servisi ingress host adı ilə yoxlayanda işləyirdi. HAProxy backend-ini ingress controller-ə
yönəldəndən sonra müştərilər bunu aldı:

```
404 Not Found — nginx
```

## Kök səbəb

Ingress controller sorğuları HTTP `Host` başlığına görə yönləndirir. Müştərilər illərdir istifadə
etdikləri `orders.corp.example` adına müraciət edirdi, amma Ingress qaydası yeni daxili ad üçün
yaradılmışdı. HAProxy müştərinin `Host` başlığını dəyişmədən ötürür, ona görə heç bir qayda uyğun gəlmədi.

Əks səhv də eyni dərəcədə yayılıb: problemi "düzəltmək" üçün HAProxy-də
`http-request set-header Host ...` yazmaq. Bu, müştərinin real adını gizlədir və mütləq URL quran
tətbiqləri (WSDL endpoint-ləri, redirect-lər) sındırır.

## Həll

1. **Ingress host-u müştərilərin artıq istifadə etdiyi adla eyni et**:
   ```yaml
   rules:
     - host: orders.corp.example
   ```
2. **Keçiddən əvvəl yoxla.** Müştərinin Host başlığını birbaşa ingress controller-ə göndər:
   ```bash
   curl -s -H 'Host: orders.corp.example' http://<ingress-lb-ip>/actuator/health
   curl -s -H 'Host: orders.corp.example' http://<ingress-lb-ip>/ws/orders?wsdl | head
   ```
3. **HAProxy-də bir sətri dəyişərək keç.** Bax: [`examples/haproxy/backend-cutover.cfg`](../../examples/haproxy/backend-cutover.cfg):
   ```
   # server vm1 10.0.10.21:9180 check        # köhnə
   server k8s 10.0.50.250:80 check           # yeni: ingress controller
   ```
4. Eyni curl komandaları ilə **HAProxy vasitəsilə** yenidən yoxla.
5. Geri qaytarma: köhnə sətrin şərhini aç, sonra `haproxy -c -f haproxy.cfg && systemctl reload haproxy`.

## Kömək edən xırda şeylər

- **Service portunu standartlaşdır** (bütün servislər üçün 8080). Onda Ingress backend-i həmişə
  eyni olur, servislər arasında yalnız `containerPort` fərqlənir.
- **Yaradılan URL-ləri yoxla.** SOAP servisləri üçün WSDL-dəki `soap:address`-i keçiddən əvvəl
  və sonra müqayisə et. Tətbiqin düzgün host və portu görüb-görmədiyi dərhal bilinir.
- **Spring Boot-un health cavabı Kubernetes-də dəyişir:** cavaba `"groups":["liveness","readiness"]`
  əlavə olunur. Bu gözləniləndir, xəta deyil. Probe-ları `/actuator/health/liveness` və
  `/actuator/health/readiness`-ə yönəlt və yalnız yoxladığın path-lərdən istifadə et.
