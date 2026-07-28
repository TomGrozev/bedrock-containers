# Contributing to bedrock-containers

This guide describes how to add and harden a new application image. Every image in
this repo follows the same rules so that all of them run under the Kubernetes
`restricted` Pod Security Standard with a read-only root filesystem.

## Quick start

Scaffold a new app from the template:

```sh
scripts/new-app.sh <app-name>
```

This copies `templates/app/` into `apps/<app-name>/`, substitutes the app name,
and makes `entrypoint.sh` executable. Then edit the remaining placeholders (search
for `<`) and commit.

## Hardening standard (non-negotiable)

Every image MUST:

1. **Wolfi base** — the final stage starts from `cgr.dev/chainguard/wolfi-base:latest`
   (Renovate keeps it current). Install runtime deps with `apk add --no-cache`.
2. **Rootless** — end with `USER 65532:65532`. Never `USER root`/`USER 0` in the
   final stage. Copy files with `--chown=65532:65532` so nothing requires root to
   read or write at runtime.
3. **Unprivileged port** — listen on a port > 1024. If the app defaults to a
   privileged port, override it (e.g. `ENV PORT=...`) so `CAP_NET_BIND_SERVICE` is
   never required.
4. **No capabilities** — the image must not require any Linux capability. Any
   deviation must be documented in the app README and flagged for review.
5. **Read-only root filesystem** — design for `readOnlyRootFilesystem: true`:
   - **Consolidate all ephemeral writes into a single `/tmp` emptyDir mount** via
     baked symlinks (recommended). Bake symlinks such as `/app/env -> /tmp/bedrock/env`
     and `/app/node_modules/.prisma -> /tmp/bedrock/prisma-client`, and have the
     entrypoint create `/tmp/bedrock/<subdir>` at startup. One bounded writable
     region is a smaller attack surface than many scattered emptyDirs; the
     trade-off is a single `sizeLimit` instead of per-path limits.
   - **Persistent** paths (uploads, databases) still need their own mount (PVC).
   - Read-only data baked into the image (e.g. schema files) does NOT need a mount
     — but ensure it is world-readable (`chmod a+rX`) if the workload might run as
     a different non-root uid than the image's `65532`.
   - Document the required writable mounts in `apps/<app>/README.md`.
   - Never write outside the declared writable paths.
6. **tini as PID 1** — use `tini --` for signal forwarding / zombie reaping:
   `ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]`.
  7. **Scanned** — CI runs Grype and fails on HIGH/CRITICAL. If a HIGH/CRITICAL
     finding is inherited from the upstream app and not patchable here (a
     won't-fix), accept it by adding its ID to `apps/<app>/.grype.yaml` (the
     single source of truth) with a `reason`. `apps/<app>/SECURITY.md` is
     **auto-generated** from that file by `scripts/gen-security-md.py` — never
     edit it by hand. CI keeps the two in sync and fails a PR whose
     `SECURITY.md` is out of date; the build still fails on any NEW high/critical
     finding.

## File layout

Each app lives under `apps/<name>/`:

| File | Required | Purpose |
|---|---|---|
| `Dockerfile` | yes | Wolfi-based, rootless image definition |
| `entrypoint.sh` | yes | runtime setup, then `exec` the app |
| `docker-bake.hcl` | yes | local build config (mirrors CI) |
| `.dockerignore` | yes | keep the build context minimal |
| `.grype.yaml` | yes | accepted-vuln ignore list — single source of truth |
| `SECURITY.md.tmpl` | yes | template for the auto-generated `SECURITY.md` |
| `README.md` | yes | app hardening/mounts/env/deploy docs (see template) |

## Dockerfile conventions

- Pin the upstream version in an `ARG VERSION` with a renovate annotation so
  Renovate bumps it automatically:
  ```dockerfile
  ARG VERSION=1.6
  # renovate: datasource=docker depName=<upstream-repo>
  ```
- **Re-layer pattern (default)** — use an `upstream` stage to copy the app from an
  upstream image:
  ```dockerfile
  FROM <upstream>:${VERSION} AS upstream
  ...
  FROM cgr.dev/chainguard/wolfi-base:latest AS final
  COPY --chown=65532:65532 --from=upstream /app /app
  ```
- **Binary-download pattern (alternative)** — if upstream publishes a release
  tarball / package instead of an image, download it with `curl` + `tar`/`dpkg` in
  a build stage, then copy into the final Wolfi stage.
- Install only the runtime deps the app needs; keep the list minimal.
- **Consolidate ephemeral writable dirs via symlinks** (recommended):
  ```dockerfile
  RUN rm -rf /app/env /app/logs /app/node_modules/.prisma /var/spool/cron \
      && ln -s /tmp/bedrock/env /app/env \
      && ln -s /tmp/bedrock/logs /app/logs \
      && ln -s /tmp/bedrock/prisma-client /app/node_modules/.prisma \
      && ln -s /tmp/bedrock/cron /var/spool/cron
  ```
- When you copy an **upstream startup script** that contains a root-dependent or
  broken block (e.g. setuid `crontab`, Alpine `dcron`), strip that block from the
  copy with `sed` **and** add a build-time guard that fails the build if the block
  remains (so an upstream reformat is caught, not silently re-introduced). See
  `apps/sprout-track` for the pattern.

## entrypoint.sh conventions

- `set -eu` (and `set -o pipefail` if using bash).
- At startup, create the single writable region the symlinks resolve into:
  ```sh
  mkdir -p /tmp/bedrock/env /tmp/bedrock/logs /tmp/bedrock/prisma-client /tmp/bedrock/cron/crontabs
  ```
- Never rely on setuid binaries (e.g. `crontab`) or root-only syscalls. If upstream
  did so, replace the mechanism with a rootless equivalent — see `apps/sprout-track`
  for an example (`busybox crond` instead of Alpine `dcron`).
- If you strip an upstream cron/init block, your entrypoint owns that mechanism
  entirely — make it the only one in the image.
- Degrade gracefully: if a required writable path is missing under a read-only root
  fs, warn on stderr and continue rather than crash.
- Finish with `exec "$@"` (or `exec <upstream-startup> "$@"` when preserving an
  upstream startup script).

## Renovate

- The Wolfi base image (`FROM cgr.dev/chainguard/wolfi-base`) is updated
  automatically by Renovate's docker manager.
- Each app's upstream version is tracked via the `# renovate:` annotation on
  `ARG VERSION`; a custom regex manager in `renovate.json5` keeps it current.

## CI

`.github/workflows/build.yml` on push to `main` (and on pull requests, without pushing):

1. Discovers every `apps/*/` directory.
2. Builds multi-arch (`linux/amd64`, `linux/arm64`) with Buildx.
  3. Runs Hadolint and Grype (fail on HIGH/CRITICAL). Grype uses each app's
     `.grype.yaml` as an ignore list for intentionally-accepted vulns and
     auto-regenerates `SECURITY.md`; the gate still fails on any NEW
     high/critical finding. A pull-request comment summarizes the scan.
4. Pushes to `ghcr.io/tomgrozev/bedrock-containers/<app>` (tagged `latest` + date)
   and makes the package public.

The template lives under `templates/app/` (outside `apps/`) so CI does not try to
build it. New app dirs are picked up automatically — no CI edits required.

## Per-app README

Every app README MUST include:

- a **Security posture** table (user, port, capabilities, root fs, init),
- the **Required writable mounts** table for read-only root fs,
- the **Environment** variables the image responds to,
- a **restricted deployment** example snippet,
- a **Known vulnerabilities & acceptance** section linking to the generated
  `SECURITY.md` (see template and `scripts/gen-security-md.py`).
