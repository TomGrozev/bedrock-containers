# sprout-track

A hardened, rootless, read-only-root-filesystem re-layer of
[`sprouttrack/sprout-track`](https://github.com/Oak-and-Sprout/sprout-track)
(Node 22 / Next.js / Prisma) onto [Wolfi](https://www.chainguard.dev/chainguard-images).

## What it does

The upstream image's `docker-startup.sh` provisions the database (Prisma
generate/migrate/seed) and then runs `npm start` (`next start` on port 3000).
This image preserves that startup flow but:

- re-layers the application onto a minimal Wolfi base,
- runs as a non-root user (`65532:65532`),
- **completely replaces** the upstream's **setuid `crontab` + Alpine `dcron`**
  notification cron with a **rootless `busybox crond`** that runs as the runtime
  user. The upstream cron block is stripped from the copied `docker-startup.sh`
  (with a build-time guard that fails the build if the block remains), so the
  entrypoint's cron is the only one in the image.

The in-pod cron is active only when `ENABLE_NOTIFICATIONS=true`. When enabled, the
entrypoint writes a crontab (for the runtime user) that POSTs to the app's
`/api/notifications/cron` endpoint every minute, then launches `crond` in the
background before handing off to the upstream startup script. The
`/api/notifications/cron` endpoint is itself gated by a DB flag, so firing while
notifications are disabled at the app level is a harmless no-op.

> **Choosing a cron mode.** This image gives you two options:
> - **In-pod cron (the replacement):** set `ENABLE_NOTIFICATIONS=true` and mount
>   `/var/spool/cron` (emptyDir/tmpfs). Drop the external K8s CronJob.
> - **External cron:** keep `ENABLE_NOTIFICATIONS=false` (no `/var/spool/cron`
>   mount) and drive `/api/notifications/cron` from a K8s CronJob.

## Security posture

Designed for the Kubernetes `restricted` Pod Security Standard:

| Control | Value |
|---|---|
| User | `65532:65532` (non-root; no `CAP_SETUID` needed) |
| Port | `3000` (unprivileged — no `CAP_NET_BIND_SERVICE`) |
| Capabilities | none (`drop: [ALL]`) |
| Root filesystem | read-only |
| Init | `tini` (PID 1, signal forwarding / zombie reaping) |

## Required writable mounts (read-only root fs)

Under `readOnlyRootFilesystem: true` each of these **must** be a writable mount.
The Prisma schema (`/app/prisma`) is **baked into the image and read-only** — it
does NOT need a mount, and the `copy-prisma-schemas` init container is NOT needed
with this image. `/var/run` is unused. SQLite-only paths are optional when using
`DATABASE_PROVIDER=postgresql`.

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir | general temp (image processing, etc.) |
| `/app/env` | emptyDir | persisted env file (bootstrapped by the startup script) |
| `/app/Files` | PVC | uploaded files (persistent) |
| `/app/logs` | emptyDir | notification / app log files |
| `/app/node_modules/.prisma` | emptyDir | generated Prisma client |
| `/var/spool/cron` | emptyDir / tmpfs | crontab spool — **only when `ENABLE_NOTIFICATIONS=true`** |
| `/db` | PVC / emptyDir | SQLite databases — **only when `DATABASE_PROVIDER=sqlite`** |

If `ENABLE_NOTIFICATIONS=true` but `/var/spool/cron` is not writable (e.g. the mount
is missing under a read-only root fs), the entrypoint logs a warning and skips the
in-pod cron rather than crashing — the app still starts.

## Environment

The image ships with SQLite defaults so a standalone `docker run` works. For
production, override at least:

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_PROVIDER` | `sqlite` | use `postgresql` for HA |
| `DATABASE_URL` | `file:/db/baby-tracker.db` | postgres URI when using postgresql |
| `LOG_DATABASE_URL` | `file:/db/baby-tracker-logs.db` | postgres URI for logs |
| `APP_URL` | — | public URL |
| `ENABLE_NOTIFICATIONS` | `false` | set `true` to enable the in-pod cron (requires `/var/spool/cron` mount) |
| `NOTIFICATION_CRON_SECRET` | — | required when notifications are enabled |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | — | web-push keys |
| `COOKIE_SECURE` | — | set `true` behind TLS |
| `PORT` | `3000` | |
| `NODE_ENV` | `production` | |

## Example deployment (restricted Pod Security, in-pod cron)

```yaml
controllers:
  app:
    type: deployment
    pod:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault
    containers:
      app:
        image:
          repository: ghcr.io/tomgrozev/bedrock-containers/sprout-track
          tag: latest        # pin by digest in production
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]
        env:
          - {name: DATABASE_PROVIDER, value: postgresql}
          - {name: ENABLE_NOTIFICATIONS, value: "true"}
          # DATABASE_URL, LOG_DATABASE_URL, APP_URL, NOTIFICATION_CRON_SECRET,
          # VAPID_* etc.

persistence:
  env:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /app/env}]}}
  Files:
    type: persistentVolumeClaim
    size: 2Gi
    advancedMounts: {app: {app: [{path: /app/Files}]}}
  logs:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /app/logs}]}}
  prisma-client:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /app/node_modules/.prisma}]}}
  tmp:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /tmp}]}}
  cron-spool:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /var/spool/cron}]}}
```

No init container is required — the Prisma schema is baked into the image.

## Local build

```sh
docker buildx bake -f apps/sprout-track/docker-bake.hcl image-local
```
