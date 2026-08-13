# muxarr

A hardened, rootless, read-only-root-filesystem re-layer of
[`ghcr.io/kirovair/muxarr`](https://github.com/KirovAir/muxarr)
(.NET 10 / ASP.NET Core Blazor Server, Debian 12 / glibc based upstream image)
onto [Wolfi](https://www.chainguard.dev/chainguard-images).

## What it does

muxarr is a media file optimization tool that strips unwanted audio and subtitle
tracks from video files (MKV / MP4 / M4V / WebM) without re-encoding, using
`mkvmerge` and `ffmpeg` for remuxing. It integrates with Sonarr / Radarr for
automatic processing of newly imported media, and exposes a Blazor Server web UI
for configuration and monitoring.

The upstream image runs as root and uses PUID/PGID remapping + `gosu` to drop
privileges at startup. This image preserves the upstream's startup flow but:

- re-layers the published .NET app onto a minimal Wolfi base,
- runs as a **fixed rootless user (`65532:65532`)** — the upstream's PUID/PGID
  + `gosu` mechanism is dropped entirely since the upstream entrypoint only ever
  chowns `/app` (read access, not writes) and `/data` (which this image bakes
  ownership for at build time instead),
- **extracts `mkvtoolnix` binaries from the upstream's own Debian 12 image**
  (mkvtoolnix has no Wolfi/Chainguard apk package — verified against
  wolfi-dev/os). Rather than building from source, the `mkvmerge` / `mkvpropedit`
  binaries are copied out of the upstream image together with their *complete*
  glibc shared-library closure (via `ldd`, including `libc` / `ld-linux`
  themselves) into an isolated directory (`/usr/local/lib/mkvtoolnix`), and
  invoked through thin wrapper scripts at `/usr/local/bin/mkvmerge` /
  `mkvpropedit` that call the extracted dynamic linker directly
  (`ld-linux... --library-path /usr/local/lib/mkvtoolnix <binary>`). This fully
  isolates Debian's glibc from Wolfi's own glibc — no global `LD_LIBRARY_PATH`,
  so it cannot interfere with the .NET runtime or anything else in the image.
- `ffmpeg` / `ffprobe` come from Wolfi's own native `ffmpeg-8.1` package (no
  extraction needed — only mkvtoolnix lacks a Wolfi package). The app resolves
  all four binaries (`ffmpeg`, `ffprobe`, `mkvmerge`, `mkvpropedit`) as bare
  `$PATH` lookups (confirmed in `Muxarr.Core/FFmpeg/FFmpeg.cs` and
  `Muxarr.Core/MkvToolNix/*.cs` upstream), so no app-side config is needed for
  binary paths.

## Security posture

Designed for the Kubernetes `restricted` Pod Security Standard:

| Control | Value |
|---|---|
| User | `65532:65532` (non-root, fixed — no PUID/PGID remap, no `gosu`, no `CAP_SETUID`) |
| Port | `8183` (unprivileged — no `CAP_NET_BIND_SERVICE`, via `ASPNETCORE_HTTP_PORTS`) |
| Capabilities | none (`drop: [ALL]`) |
| Root filesystem | read-only |
| Init | `tini` (PID 1, signal forwarding / zombie reaping) |

## Mounts (read-only root fs)

All **ephemeral** writes are consolidated into a **single `/tmp` emptyDir mount**.
The entrypoint creates `/tmp/bedrock/home` (`$HOME`) at startup, which is the
sole write target — used by ASP.NET Core's Data Protection key ring. This is one
bounded writable region (smaller attack surface) at the cost of a single
`sizeLimit` instead of per-path limits. **Persistent** paths need their own
mounts.

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir (single writable region) | ephemeral writes: `$HOME` (ASP.NET Core Data Protection key ring) |
| `/data` | PVC / emptyDir | SQLite database (`/data/muxarr.db` + `-shm` / `-wal` files) |
| `/media` | PVC | user's media library — muxarr mutates files in place (strips tracks) |

> **Known limitation — Data Protection keys are ephemeral.** ASP.NET Core's Data
> Protection key ring is written under `$HOME` (`/tmp/bedrock/home`) with no
> encrypted key storage configured. Keys are **not** persisted across restarts,
> so any auth cookies / sessions reset on redeploy. This is upstream's own
> default behaviour for ephemeral single-container deployments (the runtime
> warns: `WRN No XML encryptor configured. Key {...} may be persisted to storage
> in unencrypted form.`), but the read-only rootfs makes it unconditional rather
> than optional. Accepted trade-off for this hardening.

## Environment

muxarr's own app-level config (Sonarr / Radarr connections, processing rules,
etc.) is managed through its web UI / SQLite database at `/data/muxarr.db`, not
environment variables — the connection string is fixed to `/data/muxarr.db` in
the app's own `appsettings.json`.

| Variable | Default | Notes |
|---|---|---|
| `ASPNETCORE_HTTP_PORTS` | `8183` | HTTP listen port (unprivileged) |
| `TZ` | `UTC` | timezone |
| `HOME` | `/tmp/bedrock/home` | Data Protection key ring location (ephemeral — see above) |

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
          repository: ghcr.io/tomgrozev/bedrock-containers/muxarr
          tag: latest        # pin by digest in production
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
  media:
    type: persistentVolumeClaim
    size: 100Gi              # size per your media library
    advancedMounts: {app: {app: [{path: /media}]}}
```

No init container is required — the entrypoint creates the `$HOME` directory
under `/tmp` at startup.

## Known vulnerabilities & acceptance

Images are scanned with Grype (HIGH/CRITICAL) in CI. If a finding is inherited
from the upstream application and not patchable without forking/rebuilding the
app, it can be **accepted**:

1. Add the vulnerability ID to `apps/muxarr/.grype.yaml` (the single source of
   truth) with a short `reason`.
2. Regenerate the documentation: `python3 scripts/gen-security-md.py apps/muxarr`
   (CI also does this automatically and fails the PR if it is out of date).
3. The image carries an `org.opencontainers.image.documentation` label pointing
   at the generated `SECURITY.md`.

Do **not** edit `SECURITY.md` by hand — it is generated from `.grype.yaml`.

**Risk context for the currently accepted findings.** As of this writing,
`.grype.yaml` accepts 17 vulnerability IDs — 11 in FFmpeg (`ffmpeg-8.1`), 5 in
libssh, and 1 in OpenSSL (`libcrypto3` / `libssl3` / `openssl-dev`). These are
not cases where a fix exists and we chose not to apply it: every one is unfixed
upstream in the affected project itself (FFmpeg's fixes have not shipped in any
branch including 7.x, so downgrading does not help). They will clear
automatically via Renovate once Wolfi ships patched packages — operators should
merge those PRs promptly. muxarr's core function is running `ffmpeg` /
`mkvmerge` against user-supplied video files, which is exactly the
untrusted-input path this class of vulnerability would be exploited through — a
materially different risk profile than a stale npm devDependency CVE. For
risk-averse deployments: `/media` should only ever point at trusted/scanned
input.

## Local build

```sh
cd apps/muxarr && docker buildx bake -f docker-bake.hcl image-local
```

> **Note:** the bake file has no `context` attribute, so the build context is
> the current directory. The `Dockerfile`'s `COPY entrypoint.sh` expects the
> build context to be `apps/muxarr/` (CI supplies this via `source: apps/<app>`
> in `docker/bake-action@v7`). Running the bake from the repo root with
> `-f apps/muxarr/docker-bake.hcl` will fail because `entrypoint.sh` is not at
> the repo root.

## Build notes

- **mkvtoolnix is extracted, not built.** mkvtoolnix has no Wolfi/Chainguard apk
  package (verified against wolfi-dev/os). The `mkvtoolnix-extract` stage copies
  `mkvmerge` / `mkvpropedit` and their full glibc shared-library closure
  (including `libc` / `ld-linux` themselves) from the upstream's Debian 12 image
  into an isolated directory. Thin wrapper scripts at `/usr/local/bin/mkvmerge`
  / `mkvpropedit` invoke the extracted dynamic linker directly with
  `--library-path` pointed at the private lib dir — no global
  `LD_LIBRARY_PATH`, no interference with the .NET runtime or Wolfi's own glibc.
- **ffmpeg is Wolfi-native.** `ffmpeg` / `ffprobe` come from Wolfi's own
  `ffmpeg-8.1` package and need no special handling.
