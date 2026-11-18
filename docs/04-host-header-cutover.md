**English** | [Azərbaycanca](az/04-host-header-kecid.md)

# 4. Host header and ingress routing at cutover

## Symptom

The service worked when I tested it on the ingress hostname. After pointing the HAProxy backend at
the ingress controller, clients got:

```
404 Not Found — nginx
```

## Root cause

An ingress controller routes by the HTTP `Host` header. The clients were calling
`orders.corp.example`, the name they had used for years, but the Ingress rule was created for a
new internal name. HAProxy forwards the client's `Host` unchanged, so no rule matched.

The opposite mistake is just as common: adding `http-request set-header Host ...` in HAProxy to
"fix" it. That hides the real client name and breaks apps that build absolute URLs (WSDL
endpoints, redirects).

## Fix

1. Make the **Ingress host equal to the name clients already use**:
   ```yaml
   rules:
     - host: orders.corp.example
   ```
2. **Test before switching**, by sending the client's Host header straight to the ingress controller:
   ```bash
   curl -s -H 'Host: orders.corp.example' http://<ingress-lb-ip>/actuator/health
   curl -s -H 'Host: orders.corp.example' http://<ingress-lb-ip>/ws/orders?wsdl | head
   ```
3. **Switch by changing one line** in HAProxy, see [`examples/haproxy/backend-cutover.cfg`](../examples/haproxy/backend-cutover.cfg):
   ```
   # server vm1 10.0.10.21:9180 check        # old
   server k8s 10.0.50.250:80 check           # new: ingress controller
   ```
4. Test again **through HAProxy** with the same curl commands.
5. Rollback = uncomment the old line, then `haproxy -c -f haproxy.cfg && systemctl reload haproxy`.

## Small things that helped

- **Standardize the Service port** (8080 for every service), so the Ingress backend is always the
  same and only `containerPort` differs per app.
- **Check generated URLs.** For SOAP services, compare the WSDL `soap:address` before and after.
  It shows immediately whether the app sees the correct host and port.
- **Spring Boot health output changes on Kubernetes:** the response gains
  `"groups":["liveness","readiness"]`. That's expected, not a bug. Point probes at
  `/actuator/health/liveness` and `/actuator/health/readiness`, and only at paths you have verified.
