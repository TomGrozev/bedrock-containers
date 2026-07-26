# bedrock-containers

> Hardened, rootless container images for self-hosted applications.

Every image is **Wolfi-based**, **rootless** (`65532:65532`), **read-only-root-filesystem** compatible, **Renovate-managed**, and **Grype-scanned** (fails on HIGH/CRITICAL). All of them run under the Kubernetes `restricted` Pod Security Standard.

## Apps

| Image | Upstream | Notes |
|---|---|---|
| [`ghcr.io/tomgrozev/sprout-track`](apps/sprout-track/README.md) | [`sprouttrack/sprout-track`](https://github.com/Oak-and-Sprout/sprout-track) (Node 22 / Next.js / Prisma) | Replaces upstream setuid/`dcron` notification cron with a rootless `busybox crond`. |

Each app has its own README with the security posture, required writable mounts, environment variables, and a deployment example.

## Using an image

Pull from GHCR:

```sh
docker pull ghcr.io/tomgrozev/sprout-track:latest
```

Reference it in a Kubernetes manifest:

```yaml
image:
  repository: ghcr.io/tomgrozev/sprout-track
  tag: latest          # pin by digest in production
```

Always pin by digest in production for reproducibility.

### Restricted deployment example

These images need no capabilities and no root. Drop them straight into a `restricted` workload:

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
      image: ghcr.io/tomgrozev/sprout-track:latest
      securityContext:        # container-level
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        capabilities:
          drop: ["ALL"]
```

Because the root filesystem is read-only, **every writable path must be a mount** (emptyDir / tmpfs / PVC). See each app's README for its required mounts.

## Hardening posture

Every image in this repo:

- runs as a **non-root user** (`65532:65532`),
- listens on an **unprivileged port** (>1024) — no `CAP_NET_BIND_SERVICE`,
- requires **no Linux capabilities** (`drop: [ALL]`),
- is **read-only-root-filesystem** compatible — all runtime writes go to declared mounts,
- forwards signals and reaps zombies via **`tini`** as PID 1,
- is **scanned by Grype** on every build (fails on HIGH/CRITICAL).

## Local development

Build a single app locally with Docker Buildx Bake:

```sh
docker buildx bake -f apps/sprout-track/docker-bake.hcl image-local
```

## Contributing

### Add a new app

```sh
scripts/new-app.sh <app-name>
```

This scaffolds `apps/<app-name>/` from `templates/app/`. Fill in the placeholders, commit, and CI picks it up automatically.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full hardening standard and authoring conventions.

### Repository layout

```
bedrock-containers/
├── apps/
│   └── <app>/
│       ├── Dockerfile          # Wolfi-based, rootless image definition
│       ├── docker-bake.hcl     # local build config
│       ├── entrypoint.sh       # runtime entrypoint
│       ├── .dockerignore
│       └── README.md           # app-specific hardening, mounts, env, deploy snippet
├── templates/app/              # copy-ready scaffold for new apps
├── scripts/new-app.sh         # scaffold a new app from the template
├── .github/workflows/build.yml # build + scan + push to GHCR
├── CONTRIBUTING.md             # hardening rules + authoring guide
└── renovate.json5
```

### How it works

On every push to `main` (and on pull requests, without pushing), CI:

1. Discovers every `apps/*` directory.
2. Builds a multi-arch (`linux/amd64`, `linux/arm64`) image with Buildx.
3. Runs Hadolint and **Grype** (fails on HIGH/CRITICAL).
4. Pushes to **GHCR** (`ghcr.io/tomgrozev/<app>`, tagged `latest` + date) and makes the package public.

Renovate opens PRs to bump the Wolfi base image (`cgr.dev/chainguard/wolfi-base`) and each app's upstream version (tracked via a `# renovate:` annotation on `ARG VERSION` in the Dockerfile).

## License

Apache 2.0 — see [LICENSE](LICENSE).
