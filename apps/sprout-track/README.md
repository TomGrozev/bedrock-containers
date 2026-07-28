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
  notification cron with a **rootless background-loop** notification ping (a `curl`
  loop in `entrypoint.sh`, no `crond` daemon required). The upstream cron block is
  stripped from the copied `docker-startup.sh` (with a build-time guard that fails
  the build if the block remains), so the entrypoint's loop is the only notification
  trigger in the image.

The in-pod cron is active only when `ENABLE_NOTIFICATIONS=true`. When enabled, the
entrypoint writes a crontab (for the runtime user) that POSTs to the app's
`/api/notifications/cron` endpoint every minute, then launches `crond` in the
background before handing off to the upstream startup script. The
`/api/notifications/cron` endpoint is itself gated by a DB flag, so firing while
notifications are disabled at the app level is a harmless no-op.

> **Choosing a cron mode.** This image gives you two options:
> - **In-pod ping (the replacement):** set `ENABLE_NOTIFICATIONS=true` and the
>   entrypoint runs a rootless `curl` loop that POSTs to `/api/notifications/cron`
>   every 60s (the `/var/spool/cron` spool is no longer used). Drop the external
>   K8s CronJob.
> - **External cron:** keep `ENABLE_NOTIFICATIONS=false` (no cron needed) and
>   drive `/api/notifications/cron` from a K8s CronJob.

## Security posture

Designed for the Kubernetes `restricted` Pod Security Standard:

| Control | Value |
|---|---|
| User | `65532:65532` (non-root; no `CAP_SETUID` needed) |
| Port | `3000` (unprivileged — no `CAP_NET_BIND_SERVICE`) |
| Capabilities | none (`drop: [ALL]`) |
| Root filesystem | read-only |
| Init | `tini` (PID 1, signal forwarding / zombie reaping) |

## Mounts (read-only root fs)

All **ephemeral** writes are consolidated into a **single `/tmp` emptyDir mount**
via baked symlinks (`/app/env`, `/app/logs`, `/app/node_modules/.prisma`, and the
cron spool all resolve into `/tmp/bedrock/*`, created by the entrypoint at
startup). This is deliberate: one bounded writable region is a smaller attack
surface than several scattered emptyDirs. The trade-off is that per-path
`sizeLimit`s are replaced by a single limit on `/tmp`.

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir (single writable region) | all ephemeral writes: env, logs, Prisma client, temp, cron spool |
| `/app/Files` | PVC | uploaded files (persistent) |
| `/db` | PVC / emptyDir | SQLite databases — **only when `DATABASE_PROVIDER=sqlite`** |

The Prisma schema (`/app/prisma`) is **baked into the image and read-only** — it
does NOT need a mount, and the `copy-prisma-schemas` init container is NOT needed
with this image.

## Environment

The image ships with SQLite defaults so a standalone `docker run` works. For
production, override at least:

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_PROVIDER` | `sqlite` | use `postgresql` for HA |
| `DATABASE_URL` | `file:/db/baby-tracker.db` | postgres URI when using postgresql |
| `LOG_DATABASE_URL` | `file:/db/baby-tracker-logs.db` | postgres URI for logs |
| `APP_URL` | — | public URL |
| `ENABLE_NOTIFICATIONS` | `false` | set `true` to enable the in-pod cron (spool is in `/tmp`) |
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
  tmp:
    type: emptyDir
    sizeLimit: 1Gi
    advancedMounts: {app: {app: [{path: /tmp}]}}
  Files:
    type: persistentVolumeClaim
    size: 2Gi
    advancedMounts: {app: {app: [{path: /app/Files}]}}
```

No init container is required — the Prisma schema is baked into the image.

## Local build

```sh
docker buildx bake -f apps/sprout-track/docker-bake.hcl image-local
```
