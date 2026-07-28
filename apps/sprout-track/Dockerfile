# syntax=docker/dockerfile:1
# Hardened, rootless re-layer of sprouttrack/sprout-track onto Wolfi.
# Designed to run under a read-only root filesystem with all capabilities dropped.
# Upstream source: https://github.com/Oak-and-Sprout/sprout-track (node:22-alpine based).

# VERSION is provided as a build arg by docker-bake.hcl (its `variable "VERSION"`),
# so the bake file is the single source of truth. No default here on purpose — build
# via `docker buildx bake` (or CI), or pass --build-arg VERSION=<x> to a bare build.
ARG VERSION
FROM sprouttrack/sprout-track:${VERSION} AS upstream

FROM cgr.dev/chainguard/wolfi-base:latest AS final

# Runtime defaults mirror the upstream image so a standalone run works (SQLite).
ENV NODE_ENV=production \
    PORT=3000 \
    TZ=UTC \
    DATABASE_PROVIDER=sqlite \
    DATABASE_URL=file:/db/baby-tracker.db \
    LOG_DATABASE_URL=file:/db/baby-tracker-logs.db \
    ENABLE_NOTIFICATIONS=false
LABEL org.opencontainers.image.documentation="https://github.com/TomGrozev/bedrock-containers/blob/master/apps/sprout-track/SECURITY.md"

# Runtime deps (all glibc, matching upstream):
#   nodejs-22         - Node runtime (upstream ships Node 22.23.1)
#   npm               - Node package manager. Wolfi's nodejs-22 does NOT bundle npm
#                       (unlike Alpine's), so it must be installed explicitly; required
#                       for `npm start` and the upstream startup script's
#                       `npm run env:ensure` / `prisma:generate`.
#   busybox           - misc core utilities
#   curl              - used by the notification ping loop to call the app
#   postgresql-client - provides pg_isready used by the upstream startup script
#   ca-certificates   - TLS trust
#   tini              - PID 1 init / signal forwarding
#   tzdata            - timezone database; the upstream /etc/TZ write is stripped, so
#                       TZ is honoured via the TZ env var + zoneinfo from this package.
RUN apk add --no-cache \
    nodejs-22 \
    npm \
    busybox \
    curl \
    postgresql-client \
    ca-certificates \
    tini \
    tzdata

# Bring the application (includes node_modules w/ Prisma engines + better-sqlite3).
# --chown so every file is owned by the runtime user — no root required at runtime.
COPY --chown=65532:65532 --from=upstream /app /app

# Bake the correct (glibc) Prisma engine binaries. The upstream Alpine image ships
# MUSL engines, but Wolfi is glibc — at runtime Prisma searches for
# `*-debian-openssl-3.0.x` and fails with "Could not find schema-engine binary".
# Running `prisma generate` once here (on the Wolfi host) downloads the
# debian-openssl engines into node_modules. The runtime re-generates the
# provider-specific client into the writable /tmp mount using these engines, so
# no network is needed at runtime. The build-time client is discarded by the
# /app/node_modules/.prisma symlink block below; only the engines persist.
RUN npm run prisma:generate

# Bring upstream's startup script and STRIP two blocks that are incompatible with a
# read-only root fs / non-root user:
#   1. The timezone block (`echo "$TZ" > /etc/TZ` + a /etc/localtime symlink) — /etc
#      is not writable at runtime, and TZ is honoured via the TZ env var + tzdata.
#   2. The notification cron block (setuid `crontab` + Alpine `dcron`, and a
#      busybox-style `crond -f -d 8`) — replaced entirely by a rootless, read-only-safe
#      background loop in entrypoint.sh (the only notification trigger in the image).
# The strip uses an awk pass that deletes each block from its marker line to the
# matching `fi` (tracking then/fi depth), so it is robust to upstream reformatting
# within those blocks. The guard fails the build if `crond` or `notification:cron:setup`
# survives the strip (e.g. upstream renamed the markers).
COPY --from=upstream /usr/local/bin/docker-startup.sh /usr/local/bin/docker-startup.sh
RUN <<'STRIP'
awk '
  /# Set up timezone for Alpine Linux/ || /if \[ "\$ENABLE_NOTIFICATIONS" = "true" \]; then/ { skip=1; if (/then[[:space:]]*$/) depth=1; else depth=0; next }
  skip && /then[[:space:]]*$/ { depth++; next }
  skip && /^[[:space:]]*fi[[:space:]]*$/ { if (--depth <= 0) skip=0; next }
  skip { next }
  { print }
' /usr/local/bin/docker-startup.sh > /usr/local/bin/docker-startup.sh.new
mv /usr/local/bin/docker-startup.sh.new /usr/local/bin/docker-startup.sh
chmod 0755 /usr/local/bin/docker-startup.sh
if grep -qE 'crond|notification:cron:setup' /usr/local/bin/docker-startup.sh; then
  echo "STRIP FAILED: crond or notification:cron:setup survived the awk pass" >&2
  exit 1
fi
STRIP

# The Prisma schemas under /app/prisma (schema.prisma AND log-schema.prisma) are
# REWRITTEN at runtime by `prisma-provider.js` to match DATABASE_PROVIDER. On a
# read-only root fs that write dies with EROFS — the script aborts at the first
# writeFileSync, so NEITHER schema ever gets rewritten (the log-schema "url must
# start with file:" error is a downstream symptom of this same crash). Fix: bake
# the schema dir under /opt (immutable) and symlink /app/prisma to a per-pod
# writable path; the entrypoint copies the baked schemas in before startup.
# Relocating the WHOLE directory (not per-file symlinks) means every schema file
# is writable regardless of which ones prisma-provider.js touches.
RUN mv /app/prisma /opt/prisma-schema \
 && chmod -R a+rX /opt/prisma-schema \
 && ln -s /tmp/bedrock/prisma-schema /app/prisma

# Consolidate every ephemeral writable path into a SINGLE /tmp emptyDir mount.
# Bake symlinks so /app/env, /app/logs, /app/node_modules/.prisma and the cron
# spool all resolve into /tmp/bedrock/<subdir>. The entrypoint creates those
# subdirs at startup (on the mounted /tmp). This is the recommended hardened
# pattern: one bounded writable region instead of several scattered emptyDirs.
RUN rm -rf /app/env /app/logs /app/node_modules/.prisma /var/spool/cron \
    && ln -s /tmp/bedrock/env /app/env \
    && ln -s /tmp/bedrock/logs /app/logs \
    && ln -s /tmp/bedrock/prisma-client /app/node_modules/.prisma \
    && ln -s /tmp/bedrock/cron /var/spool/cron

# Persistent / stateful writable dirs still need their own mounts.
RUN mkdir -p /app/Files /db \
    && chown -R 65532:65532 /app/Files /db

WORKDIR /app

# Rootless notification cron + launch.
COPY --chown=65532:65532 entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

USER 65532:65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["npm", "start"]
