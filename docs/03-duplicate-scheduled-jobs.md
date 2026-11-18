# 3. Scheduled jobs ran twice

## Symptom

During testing the new pod was healthy and HAProxy still pointed at the VM, so it should have been
a safe parallel run. But the database got **duplicate rows**, and some notifications were sent twice.

## Root cause

The application had `@Scheduled` methods (and in one case a startup job) that read from and wrote
to the database on a timer. These jobs don't depend on incoming traffic. As soon as the pod
started, it began doing the same work as the VM.

Load balancer routing protects HTTP traffic, **not background jobs**.

## Fix

**Before migration: find every self-starting job.**

```bash
grep -rnE "@Scheduled|@EventListener\(ApplicationReadyEvent|CommandLineRunner|ApplicationRunner|Quartz" src/
crontab -l; ls /etc/cron.d/        # on the VM: OS-level jobs that call the app
```

**During cutover: keep exactly one writer.**

```yaml
spec:
  replicas: 1
  strategy:
    type: Recreate        # never two pods at once, even during a rollout
```

Cutover order for services with jobs:

1. Deploy to Kubernetes with the scheduler **disabled** (`SCHEDULER_ENABLED=false`, read by
   `@ConditionalOnProperty`).
2. Verify the HTTP endpoints through the ingress.
3. Stop the app on the VM.
4. Enable the scheduler in the pod.
5. Switch HAProxy.

**Long term:** if the service needs more than one replica, use a distributed lock such as
[ShedLock](https://github.com/lukas-krecan/ShedLock) so that only one instance runs each job.
Alternatively, move the job into a Kubernetes `CronJob`.

## Lesson

Never run the app locally against a shared database "just to test" if it has schedulers. That's
the same bug on a smaller scale.
