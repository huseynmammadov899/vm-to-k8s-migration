**English** | [Azərbaycanca](az/01-konfiqdeki-sirler.md)

# 1. Secrets lived in config files

## Symptom

On the VM, `application.properties` (or Tomcat's `context.xml`) held database passwords, API keys
and Redis credentials in plain text. Copying that file into a Docker image would put every secret
into the image registry, readable by anyone who can pull it.

## Root cause

On a VM, "the file is on a server only admins can reach" was the security model. In Kubernetes the
image is shared and versioned, and so is the Git repo. The same file is now a leak.

## Fix

**Step 1: replace values with placeholders.** Spring resolves `${...}` from environment variables:

```properties
# before
spring.datasource.password=S3cr3t!
# after
spring.datasource.password=${DB_PASSWORD}
```

Use the **same name** for the property placeholder and the Vault key, so nobody has to maintain a mapping.

**Step 2: store values in Vault**, one path per service: `apps/<service>`.

**Step 3: sync into the pod with External Secrets Operator.** See [`examples/k8s/externalsecret.yaml`](../examples/k8s/externalsecret.yaml):

```yaml
spec:
  refreshInterval: 30s
  secretStoreRef: { name: vault-backend, kind: ClusterSecretStore }
  target: { name: orders-api-secrets }
  dataFrom:
    - extract: { key: apps/orders-api }
```

**Step 4: inject as environment variables.** The order of `envFrom` matters:

```yaml
envFrom:
  - configMapRef: { name: orders-api-config }   # non-secret defaults
  - secretRef:    { name: orders-api-secrets }  # listed last → wins on conflicts
```

## Gotchas I hit

- **Env vars are read once, at startup.** ESO refreshes the Secret every 30s, but the running JVM
  doesn't see the change. After rotating a value, restart the pod (`kubectl delete pod` or
  `kubectl rollout restart`). No redeploy is needed. [Reloader](https://github.com/stakater/Reloader) automates this.
- **Hostnames and ports of shared infra** (Redis, DB) also went to Vault, not into values files.
  Environments differ, and keeping all connection data in one place made reviews simpler.
- **Never print a secret while debugging.** Check its length or hash instead:
  `kubectl get secret x -o jsonpath='{.data.DB_PASSWORD}' | base64 -d | wc -c`

## Catch it earlier

`scripts/vm-discovery.sh` lists config files containing `password|secret|token|key` **without
printing their values**, so you know exactly what to move to Vault.
