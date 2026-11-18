# 5. Builds in an air-gapped network

## Symptom

The CI pipeline failed before compiling a single line:

```
Could not transfer artifact ... from/to central (https://repo.maven.apache.org/maven2): Connect timed out
toomanyrequests: Rate exceeded   # pulling base images from a public registry
```

## Root cause

On the VM, the app was built once, long ago, on someone's machine. In the new flow, every commit is
built by GitLab runners in a network with **no direct internet access**. Public registries also
rate-limit anonymous pulls.

## Fix: route everything through Nexus

| Need | Instead of | Use |
|------|-----------|-----|
| Base images (`maven`, `tomcat`, `eclipse-temurin`) | Docker Hub / public ECR | Nexus **docker proxy** repository |
| Maven dependencies | Maven Central | Nexus **maven-public** group |
| App images | — | Nexus **docker hosted** repository |

Maven mirror, see [`examples/gitlab-ci/ci-settings.xml`](../examples/gitlab-ci/ci-settings.xml):

```xml
<mirror>
  <id>nexus</id>
  <mirrorOf>*</mirrorOf>
  <url>https://nexus.example.internal/repository/maven-public/</url>
</mirror>
```

Pipeline, see [`examples/gitlab-ci/.gitlab-ci.yml`](../examples/gitlab-ci/.gitlab-ci.yml):

```yaml
variables:
  MAVEN_BUILD_IMAGE: "nexus.example.internal:8082/maven:3.9-eclipse-temurin-8"
  MAVEN_ARGS: "-s ci-settings.xml"
```

## Gotchas I hit

- **`MAVEN_OPTS` vs `MAVEN_ARGS`.** `MAVEN_OPTS` is for **JVM options** (`-Xmx`, `-Dprop=x`).
  `-s settings.xml` is a **Maven CLI argument**: put it in `MAVEN_ARGS` (Maven 3.9+ reads it) or
  pass it explicitly to `mvn`.
- **Predictable artifact name.** Set `<finalName>app</finalName>` in `pom.xml` so the Dockerfile
  can always `COPY target/app.jar`.
- **Pin base image tags** (`tomcat:9.0-jre8`, not `latest`). A proxy cache plus `latest` gives you
  a different image on each runner.
- **Shared CI templates.** One `include:` project with `build`, `image` and `deploy` jobs. Each
  service only sets a few variables, so 20 services don't drift apart.
