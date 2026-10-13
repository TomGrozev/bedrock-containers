# r3

A hardened, rootless packaging of the upstream
[`hyperlogue/r3`](https://github.com/hyperlogue/r3) release binary (a Bun
single-file compiled, glibc-linked executable published as raw per-arch
artifacts on GitHub Releases — upstream publishes no container image) onto
[Wolfi](https://www.chainguard.dev/chainguard-images).

## What it does

r3 is a self-hosted artifact review server with a web UI, an HTTP API, and an
admin CLI. State (SQLite database, artifact blobs, master token) lives under
`$XDG_STATE_HOME/r3`.

This image is **not a re-layer of an upstream image** — it downloads the pinned
release binary (`r3-linux-x64` / `r3-linux-arm64`, selected from Docker's
`TARGETARCH`) in a `fetch` stage and copies it onto a minimal Wolfi base.
Upstream publishes no checksum assets, so binary integrity relies on GitHub's
immutable release artifacts fetched over TLS (the build's `ponytail:` comment
notes the upgrade path if upstream ever ships checksums). The Dockerfile
verifies the binary's glibc shared-library closure resolves in-image at build
time (`LD_TRACE_LOADED_OBJECTS`, since Wolfi ships no `ldd`) and fails the build
if any library is missing.

## Security posture

| Control | Value |
|---|---|
| User | `65532:65532` (non-root) |
| Port | `8791` (unprivileged — no `CAP_NET_BIND_SERVICE`, via `R3_PORT`) |
| Capabilities | none (`drop: [ALL]`) |
| Root filesystem | read-only |
| Init | `tini` (PID 1, signal forwarding / zombie reaping) |

The entrypoint runs the hidden `r3 __daemon` subcommand in the **foreground**
so tini actually supervises the server and forwards SIGTERM for a graceful
shutdown. `r3 server start` would daemonize (double-fork), leaving PID 1 with
nothing to supervise.

## Mounts (read-only root fs)

All **ephemeral** writes are consolidated into a **single `/tmp` emptyDir
mount**. The entrypoint creates `/tmp/bedrock/{runtime,config,home,tmp}` at
startup (`XDG_RUNTIME_DIR` is chmod `0700` per the XDG spec); there are no
baked symlinks — the XDG env vars point there directly. This is one bounded
writable region (smaller attack surface) at the cost of a single `sizeLimit`
instead of per-path limits.

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir (single writable region) | all ephemeral writes: `$XDG_RUNTIME_DIR`, `$XDG_CONFIG_HOME`, `$HOME`, `$TMPDIR` (all under `/tmp/bedrock/*`) |
| `/data` | PVC | persistent state: `$XDG_STATE_HOME/r3` — SQLite database, artifact blobs, and the master token file `/data/r3/token` |

## Environment

| Variable | Default | Notes |
|---|---|---|
| `R3_PORT` | `8791` | HTTP listen port (unprivileged) |
| `R3_BIND` | `127.0.0.1` | the server **refuses** to bind `0.0.0.0`/`::` — only loopback or a specific interface address is allowed. In Kubernetes, set it to the pod IP via the downward API (`fieldRef` `status.podIP`). The default loopback also lets the in-container admin CLI discover the daemon — see below. |
| `R3_PUBLIC_URL` | unset | the public URL clients use; its host is accepted by the server's Host guard |
| `R3_ALLOWED_HOSTS` | unset | comma-separated exact hostnames additionally accepted by the Host guard |
| `XDG_STATE_HOME` | `/data` | persistent state root (`/data/r3`) |
| `XDG_RUNTIME_DIR` | `/tmp/bedrock/runtime` | created by the entrypoint, mode `0700` |
| `XDG_CONFIG_HOME` | `/tmp/bedrock/config` | created by the entrypoint |
| `HOME` | `/tmp/bedrock/home` | created by the entrypoint |
| `TMPDIR` | `/tmp/bedrock/tmp` | created by the entrypoint |

### Health checks

`GET /api/health` is unauthenticated, but the **Host guard still applies**.
Probes work when the request's Host header is a loopback name, the bind
address, or the `R3_PUBLIC_URL` host. With a pod-IP bind, use
`http://<pod-ip>:8791/api/health` (or add the probe host to
`R3_ALLOWED_HOSTS`).

### Admin CLI vs. remote login

`kubectl exec <pod> -- r3 server status` and `r3 auth create-key` work **only
with the default loopback bind** — the in-container CLI refuses to talk to a
non-loopback HTTP endpoint. With a pod-IP bind, log in remotely over HTTPS
using the master token on a client whose `backendUrl` is the public HTTPS URL:

```sh
kubectl exec <pod> -- cat /data/r3/token | r3 login --api-key-stdin
```

## Example deployment (restricted Pod Security)

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
          repository: ghcr.io/tomgrozev/bedrock-containers/r3
          tag: latest        # pin by digest in production
        env:
          R3_BIND:
            valueFrom:
              fieldRef: {fieldPath: status.podIP}
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]

persistence:
  tmp:
    type: emptyDir
    sizeLimit: 256Mi
    advancedMounts: {app: {app: [{path: /tmp}]}}
  data:
    type: persistentVolumeClaim
    size: 1Gi
    advancedMounts: {app: {app: [{path: /data}]}}
```

Quick local run:

```sh
docker run -d --name r3 \
  --read-only --tmpfs /tmp -p 8791:8791 \
  -v r3:/data \
  r3:2.1.0
```

(With the default loopback bind, publish the port only if you intend to reach
it from outside the container's network namespace — e.g. via `-p` — since the
server itself never listens on all interfaces.)

## Known vulnerabilities & acceptance

Images are scanned with Grype (HIGH/CRITICAL) in CI. If a finding is inherited
from the upstream application and not patchable without forking/rebuilding the
app, it can be **accepted**:

1. Add the vulnerability ID to `apps/r3/.grype.yaml` (the single source of
   truth) with a short `reason`.
2. Regenerate the documentation: `python3 scripts/gen-security-md.py apps/r3`
   (CI also does this automatically and fails the PR if it is out of date).
3. The image carries an `org.opencontainers.image.documentation` label pointing
   at the generated `SECURITY.md`.

Do **not** edit `SECURITY.md` by hand — it is generated from `.grype.yaml`.

## Local build

```sh
cd apps/r3 && docker buildx bake -f docker-bake.hcl image-local
```

> **Note:** the bake file has no `context` attribute, so the build context is
> the current directory. The `Dockerfile`'s `COPY entrypoint.sh` expects the
> build context to be `apps/r3/` (CI supplies this via `source: apps/<app>` in
> `docker/bake-action@v7`). Running the bake from the repo root with
> `-f apps/r3/docker-bake.hcl` will fail because `entrypoint.sh` is not at the
> repo root.

## Versioning

`VERSION` in `docker-bake.hcl` is tracked from the
[`hyperlogue/r3`](https://github.com/hyperlogue/r3) GitHub releases by a
dedicated `customManager` in [`renovate.json5`](../../renovate.json5)
(`datasource=github-releases`) whose `extractVersionTemplate` strips the
leading `v` from the release tags — upstream tags `v2.1.0`, the build arg wants
`2.1.0`. The generic bake-file manager explicitly excludes `apps/r3/` for this
reason.
