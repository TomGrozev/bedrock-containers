#!/usr/bin/env sh
set -eu

# Create the single writable region that every symlinked ephemeral path resolves
# into (the mounted /tmp emptyDir). Everything under /tmp/bedrock is writable at
# runtime; the baked symlinks in the image point here.
mkdir -p /tmp/bedrock/env /tmp/bedrock/logs /tmp/bedrock/prisma-client /tmp/bedrock/cron/crontabs /tmp/bedrock/prisma-schema

# Copy the baked Prisma schemas (read-only under /opt) into the writable mount so
# docker-startup.sh's `prisma-provider.js` rewrite step can mutate schema.prisma
# and log-schema.prisma on the read-only root fs.
cp -a /opt/prisma-schema/. /tmp/bedrock/prisma-schema/

# Make /app/node_modules visible to the runtime-generated Prisma client.
# The generated client lives at /tmp/bedrock/prisma-client/client/index.js (via the
# /app/node_modules/.prisma -> /tmp/bedrock/prisma-client symlink) and does
# `require('@prisma/client/runtime/library.js')`. Node's bare-specifier
# resolution walks UP from there and never reaches /app/node_modules, so the
# require fails with MODULE_NOT_FOUND even though the file exists. Symlinking
# /app/node_modules into the writable mount fixes it for the generated client
# and for ts-node-run scripts (seed.ts, etc.).
ln -s /app/node_modules /tmp/bedrock/prisma-client/node_modules
ln -s /app/node_modules /tmp/bedrock/prisma-schema/node_modules

# ts-node resolves /app/prisma (symlink -> /tmp/bedrock/prisma-schema) to its
# real path, so seed.ts's relative import '../app/api/utils/encryption' resolves
# to /tmp/bedrock/app/api/utils/encryption (which does not exist). Mirror the
# upstream /app/app layout so the relative import resolves upstream-style.
ln -s /app/app /tmp/bedrock/app

# Rootless, read-only-safe notification ping — the COMPLETE replacement for the
# upstream image's setuid `crontab` + Alpine `dcron` setup (which cannot run as a
# non-root user) and for Wolfi's missing busybox `crond`. A tiny background loop is
# the most robust option here: no pid file, no setuid, logs to stdout, and it needs
# no extra package. The upstream cron block has been stripped from docker-startup.sh;
# this loop is the only notification trigger in the image.
#
# Active only when ENABLE_NOTIFICATIONS=true. The app's /api/notifications/cron
# endpoint is itself gated by a DB flag, so firing when notifications are disabled at
# the app level is a harmless no-op.
if [ "${ENABLE_NOTIFICATIONS:-false}" = "true" ]; then
  (
    while true; do
      curl -fsS -X POST http://localhost:3000/api/notifications/cron \
        -H "Authorization: Bearer ${NOTIFICATION_CRON_SECRET:-}" \
        -H "Content-Type: application/json" --max-time 30 \
        || echo "entrypoint: notification cron ping failed" >&2
      sleep 60
    done
  ) &
fi

exec /usr/local/bin/docker-startup.sh "$@"
