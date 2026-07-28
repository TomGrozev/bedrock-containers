#!/usr/bin/env sh
set -eu

# Create the single writable region that every symlinked ephemeral path resolves
# into (the mounted /tmp emptyDir). Everything under /tmp/bedrock is writable at
# runtime; the baked symlinks in the image point here.
mkdir -p /tmp/bedrock/env /tmp/bedrock/logs /tmp/bedrock/prisma-client /tmp/bedrock/cron/crontabs

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
