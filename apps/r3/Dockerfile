# syntax=docker/dockerfile:1
# Hardened, rootless packaging of the r3 artifact-review server onto Wolfi.
# Designed to run under a read-only root filesystem with all capabilities dropped.
# Upstream source: https://github.com/hyperlogue/r3 (Bun single-file compiled binary,
# glibc-linked; published as raw per-arch executables on GitHub Releases — no image).

# VERSION is provided as a build arg by docker-bake.hcl (its `variable "VERSION"`),
# so the bake file is the single source of truth. No default here on purpose.
ARG VERSION

# Fetch the pinned release binary. Docker's TARGETARCH maps to the upstream asset
# name: amd64 -> x64, arm64 -> arm64.
FROM cgr.dev/chainguard/wolfi-base:latest AS fetch
ARG VERSION
ARG TARGETARCH
RUN apk add --no-cache curl
# ponytail: upstream publishes no checksum assets, so integrity relies on GitHub's
# immutable release artifacts over TLS. Upgrade path: pin a per-arch sha256 here if
# upstream ever ships checksums.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) r3_arch=x64 ;; \
      arm64) r3_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 -o /r3 \
      "https://github.com/hyperlogue/r3/releases/download/v${VERSION}/r3-linux-${r3_arch}"; \
    chmod 0755 /r3

FROM cgr.dev/chainguard/wolfi-base:latest AS final

# Runtime defaults. The server REFUSES to bind 0.0.0.0/:: (only loopback or a
# specific interface address is allowed), so the default stays loopback — which also
# lets the in-container CLI discover the daemon over its bootstrap socket. Every XDG
# path points at a writable location so `kubectl exec <pod> -- r3 ...` inherits the
# exact same paths the daemon uses: /data is the persistent PVC (state lives in
# $XDG_STATE_HOME/r3), everything else is ephemeral under /tmp (see README).
ENV R3_PORT=8791 \
    R3_BIND=127.0.0.1 \
    XDG_STATE_HOME=/data \
    XDG_RUNTIME_DIR=/tmp/bedrock/runtime \
    XDG_CONFIG_HOME=/tmp/bedrock/config \
    HOME=/tmp/bedrock/home \
    TMPDIR=/tmp/bedrock/tmp
LABEL org.opencontainers.image.documentation="https://github.com/tomgrozev/bedrock-containers/blob/master/apps/r3/SECURITY.md"

# Runtime deps: the binary is glibc-linked (libc/libm/libpthread/libdl + the ld.so
# interpreter), all supplied by Wolfi's glibc (already present in wolfi-base). Only
# add ca-certificates (TLS trust) and tini (PID 1 init / signal forwarding).
RUN apk add --no-cache \
    ca-certificates \
    tini

# r3 binary, plus a symlink on $PATH so `kubectl exec <pod> -- r3 ...` resolves it.
# Verify the binary's shared-library closure resolves inside the image and fail the
# build if any needed library is missing. Wolfi's glibc ships no `ldd`, so use the
# loader's own trace mode (LD_TRACE_LOADED_OBJECTS), which is what `ldd` wraps.
COPY --chown=65532:65532 --from=fetch /r3 /app/r3
RUN mkdir -p /usr/local/bin \
    && ln -s /app/r3 /usr/local/bin/r3 \
    && LD_TRACE_LOADED_OBJECTS=1 /app/r3 > /tmp/r3-ldd.txt \
    && cat /tmp/r3-ldd.txt \
    && ! grep -q 'not found' /tmp/r3-ldd.txt \
    && rm -f /tmp/r3-ldd.txt

# Persistent state (sqlite db, blobs, master token) lives in $XDG_STATE_HOME/r3 = /data/r3.
# This needs its own mount (see README); it is the only persistent path.
RUN mkdir -p /data \
    && chown -R 65532:65532 /data

WORKDIR /app

COPY --chown=65532:65532 entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

EXPOSE 8791

USER 65532:65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
