# Security — Known Vulnerabilities in `muxarr`

This image is a hardened, rootless re-layer of the upstream
[`ghcr.io/kirovair/muxarr`](https://github.com/KirovAir/muxarr) application onto
Chainguard's Wolfi base. It is scanned on every push with
[Grype](https://github.com/anchore/grype) (severity cutoff `high`).

## TL;DR
All `High`/`Critical` findings reported by Grype should be reviewed. When a
finding is inherited from the upstream application layer (copied verbatim from
the upstream image) and cannot be patched in this repo without forking/rebuilding
the app, it may be intentionally **accepted** and listed in `.grype.yaml`. The
Wolfi base itself is generally clean at `High`/`Critical`.

## Why a finding might be accepted
- It is inherited from the upstream application layer; this repo only re-layers
  and hardens the *runtime* (rootless, read-only rootfs, dropped capabilities),
  not the app code.
- A fix exists upstream but applying it here means forking/rebuilding the app —
  out of scope and potentially destabilizing.
- The app runs as a non-root user (UID 65532) under a read-only root filesystem
  with all capabilities dropped, which reduces exploitability.

## Accepted findings (High)
> This section is **auto-generated** from [`.grype.yaml`](./.grype.yaml) by
> `scripts/gen-security-md.py`. To change what is accepted, edit `.grype.yaml`
> (the single source of truth); CI keeps this file in sync. Do not edit the list
> below by hand.

_Generated from `.grype.yaml` — 19 accepted vulnerability ID(s). Edit `.grype.yaml`, not this file._

| Vulnerability ID | Reason |
| --- | --- |
| `CVE-2026-15370` | Unfixed upstream libssh CVE; tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-54876` | Unfixed upstream OpenSSL CVE (rated Low by OpenSSL — OCSP-flag-gated memory leak, not triggered by default .NET/ffmpeg TLS usage); needs OpenSSL 3.6.4. See apps/muxarr/SECURITY.md. |
| `CVE-2026-59847` | Unfixed upstream libssh CVE; tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-59849` | Unfixed upstream libssh CVE; tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-59850` | Unfixed upstream libssh CVE; tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-59851` | Unfixed upstream libssh CVE; tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-64830` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-64833` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-64834` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-64835` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-65703` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-65704` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-65705` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-65706` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-66036` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-66039` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-66040` | Unfixed upstream in FFmpeg itself as of 2026-08 (affects all branches incl. 7.x); tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-70628` | Unfixed upstream in FFmpeg 8.x; fixed only in FFmpeg 9.0 (not yet released). Tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |
| `CVE-2026-70632` | Unfixed upstream in FFmpeg 8.x; fixed only in FFmpeg 9.0 (not yet released). Tracked for automatic resolution via Renovate once a patched Wolfi package ships. See apps/muxarr/SECURITY.md. |


## How this is enforced
- A curated, app-scoped `.grype.yaml` ignore list (see above) suppresses
  specific vulnerability IDs during scanning, each with a `reason`. This keeps
  the build green for the accepted set while still **failing the build on any
  NEW `high`/`critical` finding** (e.g. in the Wolfi base or a newly
  introduced dependency).
- Grype prints suppressed findings (with the reason) in the CI scan log, and a
  pull-request comment summarizes the scan.

## Re-evaluating
When the upstream ships a release with patched dependencies (or when you choose
to rebuild the app's dependencies in the Dockerfile), remove those entries from
`.grype.yaml` and re-scan.
