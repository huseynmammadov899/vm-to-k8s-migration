[English](../05-air-gapped-builds.md) | **Azərbaycanca**

# 5. İnternetsiz şəbəkədə build

## Əlamət

CI pipeline bir sətir kod belə kompilyasiya etmədən xəta verdi:

```
Could not transfer artifact ... from/to central (https://repo.maven.apache.org/maven2): Connect timed out
toomanyrequests: Rate exceeded   # base image-ləri public registry-dən çəkərkən
```

## Kök səbəb

VM dövründə tətbiq çoxdan, bir dəfə, kiminsə kompüterində build olunmuşdu. Yeni axında isə hər
commit-i **birbaşa internet çıxışı olmayan** şəbəkədəki GitLab runner-ləri build edir. Üstəlik,
public registry-lər anonim çəkmələri limitləyir (rate limit).

## Həll: hər şeyi Nexus üzərindən keçir

| Ehtiyac | Bunun əvəzinə | Bunu istifadə et |
|---------|---------------|------------------|
| Base image-lər (`maven`, `tomcat`, `eclipse-temurin`) | Docker Hub / public ECR | Nexus **docker proxy** reposu |
| Maven asılılıqları | Maven Central | Nexus **maven-public** qrupu |
| Tətbiq image-ləri | — | Nexus **docker hosted** reposu |

Maven mirror, bax: [`examples/gitlab-ci/ci-settings.xml`](../../examples/gitlab-ci/ci-settings.xml):

```xml
<mirror>
  <id>nexus</id>
  <mirrorOf>*</mirrorOf>
  <url>https://nexus.example.internal/repository/maven-public/</url>
</mirror>
```

Pipeline, bax: [`examples/gitlab-ci/.gitlab-ci.yml`](../../examples/gitlab-ci/.gitlab-ci.yml):

```yaml
variables:
  MAVEN_BUILD_IMAGE: "nexus.example.internal:8082/maven:3.9-eclipse-temurin-8"
  MAVEN_ARGS: "-s ci-settings.xml"
```

## Qarşılaşdığım tələlər

- **`MAVEN_OPTS` və `MAVEN_ARGS` fərqi.** `MAVEN_OPTS` **JVM parametrləri** üçündür (`-Xmx`,
  `-Dprop=x`). `-s settings.xml` isə **Maven CLI arqumentidir**: onu `MAVEN_ARGS`-a yaz
  (Maven 3.9+ oxuyur) və ya birbaşa `mvn`-ə ötür.
- **Proqnozlaşdırıla bilən artifact adı.** `pom.xml`-da `<finalName>app</finalName>` yaz ki,
  Dockerfile həmişə `COPY target/app.jar` edə bilsin.
- **Base image tag-larını sabitlə** (`latest` yox, `tomcat:9.0-jre8`). Proxy cache ilə `latest`
  birlikdə hər runner-də fərqli image deməkdir.
- **Ortaq CI şablonları.** `build`, `image` və `deploy` job-ları olan bir `include:` layihəsi.
  Hər servis yalnız bir neçə dəyişən təyin edir, beləcə 20 servis bir-birindən uzaqlaşmır.
