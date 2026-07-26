# bedrock-containers

> Hardened, rootless container images for the self-hosted applications we run.

An opinionated, public collection of container images built for security and
reproducibility. Every image is:

- **Wolfi-based** — built on [Chainguard's Wolfi](https://www.chainguard.dev/chainguard-images) base (glibc, apk, minimal attack surface).
- **Rootless** — runs as a non-root user (`65532`) with no elevated capabilities.
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
│       └── .dockerignore
├── .github/workflows/build.yml # build + scan + push to GHCR
└── renovate.json5
```

Adding a new app is as simple as dropping a directory under `apps/`.

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
(Node 22 / Next.js / Prisma) onto Wolfi. The upstream image ships a
`docker-startup.sh` that provisions the database (Prisma generate/migrate/seed)
and finally runs `npm start`.

This image preserves that startup flow but replaces the upstream's broken
setuid/`dcron` notification cron with a **rootless** `busybox crond` that runs as
the runtime user. When `ENABLE_NOTIFICATIONS=true`, the entrypoint writes a crontab
(for the runtime user) that POSTs to the app's `/api/notifications/cron` endpoint
every minute, then launches `crond` in the background before handing off to the
upstream startup script. The spool directory is expected to be writable (mount it
as an emptyDir/tmpfs when running with a read-only root filesystem).

## Local development

Build a single app locally with Docker Buildx Bake:

```sh
docker buildx bake -f apps/sprout-track/docker-bake.hcl image-local
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
