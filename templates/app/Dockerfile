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
# If upstream has a startup script, bring it too (and strip any root-dependent
# cron/init block — see CONTRIBUTING.md):
# COPY --from=upstream /usr/local/bin/docker-startup.sh /usr/local/bin/docker-startup.sh
# RUN chmod 0755 /usr/local/bin/docker-startup.sh

# Consolidate every ephemeral writable path into a SINGLE /tmp emptyDir mount.
# Bake symlinks so each writable path resolves into /tmp/bedrock/<subdir>; the
# entrypoint creates those subdirs at startup on the mounted /tmp. This gives
# one bounded writable region instead of many scattered emptyDirs. Adjust the
# symlink list to the paths YOUR app actually writes to.
RUN rm -rf /app/env /app/logs /app/node_modules/.prisma /var/spool/cron \
    && ln -s /tmp/bedrock/env /app/env \
    && ln -s /tmp/bedrock/logs /app/logs \
    && ln -s /tmp/bedrock/prisma-client /app/node_modules/.prisma \
    && ln -s /tmp/bedrock/cron /var/spool/cron

# Persistent / stateful writable dirs still need their own mounts (see README).
RUN mkdir -p /app/Files /db \
    && chown -R 65532:65532 /app/Files /db

WORKDIR /app

COPY --chown=65532:65532 entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

USER 65532:65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["<APP_START_COMMAND>"]
