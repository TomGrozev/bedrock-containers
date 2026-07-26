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

## Required writable mounts (read-only root fs)

| Path | Type | Purpose |
|---|---|---|
| `/tmp` | emptyDir | general temp |
| `/var/run` | emptyDir | runtime pid / sockets |
| TODO | TODO | TODO |

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
          repository: ghcr.io/tomgrozev/<app>
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
    advancedMounts: {app: {app: [{path: /tmp}]}}
  var-run:
    type: emptyDir
    advancedMounts: {app: {app: [{path: /var/run}]}}
  # TODO: add the app-specific writable mounts from the table above.
```

## Local build

```sh
docker buildx bake -f apps/<app>/docker-bake.hcl image-local
```
