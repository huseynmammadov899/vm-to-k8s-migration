[English](../01-secrets-in-config-files.md) | **Azərbaycanca**

# 1. Sirlər konfiq fayllarında idi

## Əlamət

VM-də `application.properties` (və ya Tomcat-ın `context.xml` faylı) baza parollarını, API
açarlarını və Redis məlumatlarını açıq mətn kimi saxlayırdı. Bu faylı Docker image-ə kopyalamaq
bütün sirləri image registry-yə qoymaq deməkdir. Image-i çəkə bilən hər kəs onları oxuya bilər.

## Kök səbəb

VM-də təhlükəsizlik modeli belə idi: "fayl yalnız adminlərin girə bildiyi serverdədir". Kubernetes-də
image ortaqdır və versiyalanır, Git reposu da elə. Eyni fayl indi sızma mənbəyidir.

## Həll

**Addım 1: dəyərləri placeholder-lə əvəz et.** Spring `${...}` ifadələrini mühit dəyişənlərindən oxuyur:

```properties
# əvvəl
spring.datasource.password=S3cr3t!
# sonra
spring.datasource.password=${DB_PASSWORD}
```

Placeholder adı ilə Vault açarının adı **eyni** olsun. Onda heç kim ayrıca uyğunluq cədvəli saxlamalı olmur.

**Addım 2: dəyərləri Vault-a yaz.** Hər servis üçün bir yol: `apps/<servis>`.

**Addım 3: External Secrets Operator ilə pod-a ötür.** Bax: [`examples/k8s/externalsecret.yaml`](../../examples/k8s/externalsecret.yaml):

```yaml
spec:
  refreshInterval: 30s
  secretStoreRef: { name: vault-backend, kind: ClusterSecretStore }
  target: { name: orders-api-secrets }
  dataFrom:
    - extract: { key: apps/orders-api }
```

**Addım 4: mühit dəyişəni kimi ötür.** `envFrom` sırası vacibdir:

```yaml
envFrom:
  - configMapRef: { name: orders-api-config }   # sirr olmayan default-lar
  - secretRef:    { name: orders-api-secrets }  # sonuncudur → toqquşmada qalib gəlir
```

## Qarşılaşdığım tələlər

- **Mühit dəyişənləri yalnız bir dəfə, işə düşəndə oxunur.** ESO Secret-i hər 30 saniyədən bir
  yeniləyir, amma işləyən JVM dəyişikliyi görmür. Dəyəri dəyişəndən sonra pod-u yenidən başlat
  (`kubectl delete pod` və ya `kubectl rollout restart`). Yenidən deploy lazım deyil.
  [Reloader](https://github.com/stakater/Reloader) bunu avtomatlaşdırır.
- **Ortaq infrastrukturun host və portları** (Redis, baza) da values fayllarına yox, Vault-a getdi.
  Mühitlər fərqlidir və bütün qoşulma məlumatının bir yerdə olması review-ları sadələşdirdi.
- **Debug edərkən sirri heç vaxt çap etmə.** Bunun əvəzinə uzunluğunu və ya hash-ini yoxla:
  `kubectl get secret x -o jsonpath='{.data.DB_PASSWORD}' | base64 -d | wc -c`

## Daha erkən necə tutmaq

`scripts/vm-discovery.sh` tərkibində `password|secret|token|key` olan konfiq fayllarını
**dəyərlərini çap etmədən** siyahıya alır. Beləcə Vault-a nəyi köçürmək lazım olduğunu dəqiq bilirsən.
