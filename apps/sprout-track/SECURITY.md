# Security — Known Vulnerabilities in `sprout-track`

This image is a hardened, rootless re-layer of the upstream
[`sprouttrack/sprout-track`](https://github.com/Oak-and-Sprout/sprout-track)
application onto Chainguard's Wolfi base. It is scanned on every push with
[Grype](https://github.com/anchore/grype) (severity cutoff `high`).

## TL;DR
All `High`/`Critical` findings reported by Grype live in the **upstream
application's npm dependencies** (copied verbatim from the upstream image's
`/app`), **not** in the Wolfi base image. The Wolfi base is clean at
`High`/`Critical`. These findings are **accepted** and documented here; they
are deliberately NOT patched in this repo because fixing them requires
modifying the upstream application (rebuilding `node_modules` / bumping the
upstream release), which risks breaking the app and is outside the scope of a
hardening re-layer.

## Why we accept them
- They are inherited from the upstream application layer. This repo only
  re-layers and hardens the *runtime* (rootless, read-only rootfs, dropped
  capabilities); it does not rebuild the app.
- Every finding has an upstream fix available, but applying it here would mean
  forking/rebuilding the app — out of scope and potentially destabilizing.
- The application runs as a non-root user (UID 65532) under a read-only root
  filesystem with all capabilities dropped, which substantially reduces the
  exploitability of these server-side npm issues.

## Accepted findings (High)
> This section is **auto-generated** from [`.grype.yaml`](./.grype.yaml) by
> `gen-security-md.py`. To change what is accepted, edit `.grype.yaml` (the
> single source of truth); CI keeps this file in sync. Do not edit the list
> below by hand.

_Generated from `.grype.yaml` on 2026-07-28 — 67 accepted vulnerability ID(s). Edit `.grype.yaml`, not this file._

| Vulnerability ID | Reason |
| --- | --- |
| `CVE-2026-12143` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-13149` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-14257` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-32141` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-32887` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-33228` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-33671` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-35209` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-42033` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-42035` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-42043` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-42264` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44486` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44487` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44488` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44494` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44495` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44496` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44573` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44574` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44575` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44578` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44579` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-44705` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-45109` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-45623` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-59869` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-64641` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-64642` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-64645` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `CVE-2026-64649` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-25h7-pfq9-p65f` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-267c-6grr-h53f` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-26hh-7cqf-hhc6` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-35jp-ww65-95wh` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-36qx-fr4f-26g5` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-38f7-945m-qr2g` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-3g43-6gmg-66jw` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-3jxr-9vmj-r5cp` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-492v-c6pp-mqqv` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-52cp-r559-cp3m` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-6chq-wfr3-2hj9` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-6g55-p6wh-862q` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-6gpp-xcg3-4w24` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-737v-mqg7-c878` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-777c-7fjr-54vf` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-89xv-2m56-2m9x` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-8h8q-6873-q5fj` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-c2c7-rcm5-vvqj` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-c4j6-fc7j-m34r` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-f88m-g3jw-g9cj` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-hfxv-24rg-xrqf` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-hmw2-7cc7-3qxx` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-j5f8-grm9-p9fc` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-m99w-x7hq-7vfj` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-mg66-mrh9-m8jx` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-mh99-v99m-4gvg` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-p6gq-j5cr-w38f` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-p92q-9vqr-4j8v` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-p9j2-gv94-2wf4` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-pf86-5x62-jrwf` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-ph9p-34f9-6g65` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-pmwg-cvhr-8vh7` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-q4gf-8mx6-v5v3` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-q8qp-cvcw-x6jj` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-r28c-9q8g-f849` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |
| `GHSA-rf6f-7fwh-wjgh` | Accepted upstream npm vuln; see apps/sprout-track/SECURITY.md |


## How this is enforced
- A curated, app-scoped `.grype.yaml` ignore list suppresses these **specific**
  vulnerability IDs during scanning, each with a `reason` pointing here. This
  keeps the build green for the accepted set while still **failing the build on
  any NEW `high`/`critical` finding** (e.g. in the Wolfi base or a newly
  introduced dependency).
- Grype prints suppressed findings (with the reason) in the CI scan log, and a
  pull-request comment summarizes the scan.

## Re-evaluating
When the upstream `sprouttrack/sprout-track` ships a release with patched
dependencies (or when we choose to rebuild `node_modules` in the Dockerfile),
these entries should be removed from `.grype.yaml` and the image re-scanned.
