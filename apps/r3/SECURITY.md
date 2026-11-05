# Security — Known Vulnerabilities in `r3`

This image is a hardened, rootless packaging of the upstream
[`hyperlogue/r3`](https://github.com/hyperlogue/r3) release binary onto
Chainguard's Wolfi base. It is scanned on every push with
[Grype](https://github.com/anchore/grype) (severity cutoff `high`).

## TL;DR
All `High`/`Critical` findings reported by Grype should be reviewed. When a
finding is inherited from the upstream application layer (copied verbatim from
the upstream image) and cannot be patched in this repo without forking/rebuilding
the app, it may be intentionally **accepted** and listed in `.grype.yaml`. The
Wolfi base is normally clean at `High`/`Critical`; a base finding with no
patched package build may be accepted temporarily (see below).

## Why a finding might be accepted
- It is inherited from the upstream application layer; this repo only re-layers
  and hardens the *runtime* (rootless, read-only rootfs, dropped capabilities),
  not the app code.
- A fix exists upstream but applying it here means forking/rebuilding the app —
  out of scope and potentially destabilizing.
- No patched build of the affected package has been published yet; the finding
  is accepted temporarily and re-checked when the base is refreshed.
- The app runs as a non-root user (UID 65532) under a read-only root filesystem
  with all capabilities dropped, which reduces exploitability.

## Accepted findings (High)
> This section is **auto-generated** from [`.grype.yaml`](./.grype.yaml) by
> `scripts/gen-security-md.py`. To change what is accepted, edit `.grype.yaml`
> (the single source of truth); CI keeps this file in sync. Do not edit the list
> below by hand.

_Generated from `.grype.yaml` — 1 accepted vulnerability ID(s). Edit `.grype.yaml`, not this file._

| Vulnerability ID | Reason |
| --- | --- |
| `CVE-2026-84243` | No patched Wolfi glibc build yet (2.44-r13 installed, 2026-11-05). Exploitable only when an attacker controls LANGUAGE and LC_MESSAGES and can place a crafted .mo file readably; this image sets no LANGUAGE/LANG/LC_ALL and runs non-root with a read-only rootfs. |


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
