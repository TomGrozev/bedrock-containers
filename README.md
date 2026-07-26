# bedrock-containers

> Hardened, rootless container images for the self-hosted applications we run.

An opinionated, public collection of container images built for security and
reproducibility. Every image is:

- **Wolfi-based** — built on [Chainguard's Wolfi](https://www.chainguard.dev/chainguard-images) base (glibc, apk, minimal attack surface).
- **Rootless** — runs as a non-root user (`65532:65532`) with no elevated capabilities and no requirement for root at runtime.
- **Read-only root filesystem** — designed to run with `readOnlyRootFilesystem: true`; every writable path is an explicit mount.
- **Renovate-managed** — base image and upstream application versions are kept current automatically.
- **Scanned** — every build is checked with [Grype](https://github.com/anchore/grype); the build fails on HIGH/CRITICAL CVEs.

## Repository layout

```
bedrock-containers/
├── apps/
│   └── <app>/
│       ├── Dockerfile          # Wolfi-based, rootless image definition
│       ├── docker-bake.hcl     # local build config (optional, mirrors CI)
│       ├── entrypoint.sh       # optional runtime entrypoint
│       ├── .dockerignore
│       └── README.md           # app-specific hardening, mounts, env, deploy snippet
├── templates/app/              # copy-ready scaffold for new apps
├── scripts/new-app.sh         # scaffold a new app from the template
├── .github/workflows/build.yml # build + scan + push to GHCR
├── CONTRIBUTING.md             # hardening rules + authoring guide
└── renovate.json5
```

## Adding a new app

```sh
scripts/new-app.sh <app-name>
```

This scaffolds `apps/<app-name>/` from `templates/app/`. Then fill in the
placeholders and commit — CI picks it up automatically. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full hardening standard and conventions.

## How it works

On every push to `main` (and on pull requests, without pushing), the CI:

1. Discovers every `apps/*` directory.
2. Builds a multi-arch (`linux/amd64`, `linux/arm64`) image with Buildx.
3. Runs **Grype** and fails the build on any HIGH/CRITICAL vulnerability.
4. Pushes the image to **GHCR** (`ghcr.io/tomgrozev/<app>`), tagged `latest` and a
   date stamp, and makes the package public.

Renovate opens PRs to bump:

- the Wolfi base image (`cgr.dev/chainguard/wolfi-base`), and
- each app's upstream version (tracked via a `# renovate:` annotation on the
  `ARG VERSION` line in the Dockerfile).

## Hardening & restricted environments

These images are built to run under the Kubernetes `restricted` Pod Security
Standard. Every image:

- runs as a **non-root user** (`65532:65532`) by default,
- listens on an **unprivileged port** (>1024), so no `CAP_NET_BIND_SERVICE`,
- requires **no Linux capabilities** (`capabilities.drop: [ALL]`),
- is **read-only-root-filesystem** compatible — all runtime writes go to declared mounts,
- forwards signals and reaps zombies via `tini` as PID 1.

Recommended Pod security posture — apply this to any workload consuming these images:

```yaml
spec:
  securityContext:            # pod-level
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    fsGroup: 65532
    fsGroupChangePolicy: OnRootMismatch
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:        # container-level
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop: ["ALL"]
```

Because the root filesystem is read-only, **every writable path must be backed by a
mount** (emptyDir, tmpfs, or PVC). Each app documents its required writable mounts in
`apps/<app>/README.md`. The image pre-creates those directories and owns them by the
runtime user, but at runtime under a read-only root fs only the mounted paths are
writable — if a path the app needs is not listed, mount it.

## Consuming an image

Point your deployment at the hardened image:

```yaml
image:
  repository: ghcr.io/tomgrozev/sprout-track
  tag: latest          # or pin to a date stamp / digest
```

(Always pin by digest in production for reproducibility.)

## Apps

### sprout-track

A rootless re-layer of [`sprouttrack/sprout-track`](https://github.com/Oak-and-Sprout/sprout-track)
(Node 22 / Next.js / Prisma) onto Wolfi. The upstream image ships a `docker-startup.sh`
that provisions the database (Prisma generate/migrate/seed) and finally runs `npm start`.

This image preserves that startup flow but replaces the upstream's broken
setuid/`dcron` notification cron with a **rootless** `busybox crond` that runs as the
runtime user. When `ENABLE_NOTIFICATIONS=true`, the entrypoint writes a crontab
(for the runtime user) that POSTs to the app's `/api/notifications/cron` endpoint
every minute, then launches `crond` in the background before handing off to the
upstream startup script.

See [`apps/sprout-track/README.md`](apps/sprout-track/README.md) for the full
security posture, required writable mounts, environment variables, and a restricted
deployment example.

## Local development

Build a single app locally with Docker Buildx Bake:

```sh
docker buildx bake -f apps/sprout-track/docker-bake.hcl image-local
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
