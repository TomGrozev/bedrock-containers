# syntax=docker/dockerfile:1
# Hardened, rootless re-layer of sprouttrack/sprout-track onto Wolfi.
# Upstream source: https://github.com/Oak-and-Sprout/sprout-track (node:22-alpine based).

ARG VERSION=1.6
# renovate: datasource=docker depName=sprouttrack/sprout-track
FROM sprouttrack/sprout-track:${VERSION} AS upstream

FROM cgr.dev/chainguard/wolfi-base:latest AS final

ARG VERSION=1.6
# renovate: datasource=docker depName=sprouttrack/sprout-track

# Runtime defaults mirror the upstream image so a standalone run works (SQLite).
ENV NODE_ENV=production \
    PORT=3000 \
    TZ=UTC \
    DATABASE_PROVIDER=sqlite \
    DATABASE_URL=file:/db/baby-tracker.db \
    LOG_DATABASE_URL=file:/db/baby-tracker-logs.db \
    ENABLE_NOTIFICATIONS=false

# Runtime deps (all glibc, matching upstream):
#   nodejs-22        - Node runtime (upstream ships Node 22.23.1)
#   busybox          - provides crond for the rootless notification cron
#   curl             - used by the notification cron to ping the app
#   postgresql-client - provides pg_isready used by the upstream startup script
#   ca-certificates  - TLS trust
#   tini             - PID 1 init / signal forwarding
RUN apk add --no-cache \
    nodejs-22 \
    busybox \
    curl \
    postgresql-client \
    ca-certificates \
    tini

# Bring the application (includes node_modules w/ Prisma engines + better-sqlite3).
COPY --from=upstream /app /app
# Bring upstream's startup script (Prisma generate/migrate/seed, then execs CMD).
COPY --from=upstream /usr/local/bin/docker-startup.sh /usr/local/bin/docker-startup.sh
RUN chmod 0755 /usr/local/bin/docker-startup.sh

WORKDIR /app

# Rootless notification cron + launch.
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

USER 65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["npm", "start"]
