# syntax=docker/dockerfile:1
# Hardened, rootless re-layer of <UPSTREAM_IMAGE> onto Wolfi.
# Designed to run under a read-only root filesystem with all capabilities dropped.
# Upstream source: <UPSTREAM_SOURCE_URL>

ARG VERSION=<UPSTREAM_VERSION>
# renovate: datasource=docker depName=<UPSTREAM_IMAGE_REPO>
FROM <UPSTREAM_IMAGE>:${VERSION} AS upstream

FROM cgr.dev/chainguard/wolfi-base:latest AS final

ARG VERSION=<UPSTREAM_VERSION>
# renovate: datasource=docker depName=<UPSTREAM_IMAGE_REPO>

# Runtime defaults (mirror upstream where possible; keep the default port > 1024).
ENV NODE_ENV=production \
    PORT=3000

# Runtime deps from Wolfi (glibc). Keep this list minimal.
RUN apk add --no-cache \
    ca-certificates \
    tini
    # nodejs-22     # uncomment for Node apps
    # busybox      # uncomment if you need crond
    # curl         # uncomment if the entrypoint calls curl

# Copy the application from the upstream image, owned by the runtime user.
COPY --chown=65532:65532 --from=upstream /app /app
# If upstream has a startup script, bring it too:
# COPY --from=upstream /usr/local/bin/docker-startup.sh /usr/local/bin/docker-startup.sh
# RUN chmod 0755 /usr/local/bin/docker-startup.sh

# Pre-create every directory that must be writable at runtime and own it.
# Under readOnlyRootFilesystem these MUST be backed by writable mounts
# (see apps/<APP>/README.md).
RUN mkdir -p \
      /tmp \
      /var/run \
      <APP_WRITABLE_DIRS> \
    && chown -R 65532:65532 \
      /tmp \
      /var/run \
      <APP_WRITABLE_DIRS>

WORKDIR /app

COPY --chown=65532:65532 entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

USER 65532:65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["<APP_START_COMMAND>"]
