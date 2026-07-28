# <app>

TODO: one-paragraph description of what this image is and where the app comes from
(link the upstream source).

## What it does

TODO: describe the upstream's behaviour and what this image changes (re-layer onto
Wolfi, non-root, replaces any root/setuid mechanism, etc.).

## Security posture

| Control | Value |
|---|---|
| User | `65532:65532` (non-root) |
| Port | TODO (must be > 1024) |
| Capabilities | none (`drop: [ALL]`) |
| Root filesystem | read-only |
| Init | `tini` (PID 1) |

## Mounts (read-only root fs)

All **ephemeral** writes are consolidated into a **single `/tmp` emptyDir mount**
via baked symlinks (`/app/env`, `/app/logs`, `/app/node_modules/.prisma`, and the
cron spool resolve into `/tmp/bedrock/*`, created by the entrypoint at startup).
This is one bounded writable region (smaller attack surface) at the cost of a single
`sizeLimit` instead of per-path limits. **Persistent** paths need their own mount.

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir (single writable region) | all ephemeral writes |
| `/app/Files` | PVC | persistent uploads (if the app has any) |
| TODO | TODO | TODO persistent/path-specific mount |

## Environment

| Variable | Default | Notes |
|---|---|---|
| TODO | TODO | TODO |

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
          repository: ghcr.io/tomgrozev/bedrock-containers/<app>
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
    sizeLimit: 1Gi
    advancedMounts: {app: {app: [{path: /tmp}]}}
  # TODO: add persistent / path-specific mounts from the table above.
```

## Known vulnerabilities & acceptance

Images are scanned with Grype (HIGH/CRITICAL) in CI. If a finding is inherited
from the upstream application and not patchable without forking/rebuilding the
app, it can be **accepted**:

1. Add the vulnerability ID to `apps/<app>/.grype.yaml` (the single source of
   truth) with a short `reason`.
2. Regenerate the documentation: `python3 scripts/gen-security-md.py apps/<app>`
   (CI also does this automatically and fails the PR if it is out of date).
3. The image carries an `org.opencontainers.image.documentation` label pointing
   at the generated `SECURITY.md`.

Do **not** edit `SECURITY.md` by hand — it is generated from `.grype.yaml`.

## Local build

```sh
docker buildx bake -f apps/<app>/docker-bake.hcl image-local
```
