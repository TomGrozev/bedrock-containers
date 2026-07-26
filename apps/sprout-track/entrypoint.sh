#!/usr/bin/env sh
set -eu

# Create the single writable region that every symlinked ephemeral path resolves
# into (the mounted /tmp emptyDir). Everything under /tmp/bedrock is writable at
# runtime; the baked symlinks in the image point here.
mkdir -p /tmp/bedrock/env /tmp/bedrock/logs /tmp/bedrock/prisma-client /tmp/bedrock/cron/crontabs

# Rootless notification cron — the COMPLETE replacement for the upstream image's
# setuid `crontab` + Alpine `dcron` setup (which cannot run as a non-root user).
# The upstream cron block has been stripped from docker-startup.sh; this is the
# only cron in the image.
#
# Active only when ENABLE_NOTIFICATIONS=true. The app's /api/notifications/cron
# endpoint is itself gated by a DB flag, so firing when notifications are
# disabled at the app level is a harmless no-op.
#
# The crontab spool (/var/spool/cron -> /tmp/bedrock/cron) is writable via the
# /tmp mount. If it is not writable we skip the in-pod cron (the app still
# starts) and warn on stderr rather than crashing.
if [ "${ENABLE_NOTIFICATIONS:-false}" = "true" ]; then
  SPOOL_DIR="/var/spool/cron/crontabs"
  if ! mkdir -p "${SPOOL_DIR}" 2>/dev/null || ! [ -w "${SPOOL_DIR}" ]; then
    echo "entrypoint: ENABLE_NOTIFICATIONS=true but ${SPOOL_DIR} is not writable; skipping in-pod cron (mount /tmp as an emptyDir)." >&2
  else
    CRON_USER="$(id -un)"
    cat > "${SPOOL_DIR}/${CRON_USER}" <<EOF
* * * * * curl -fsS -X POST http://localhost:3000/api/notifications/cron -H "Authorization: Bearer ${NOTIFICATION_CRON_SECRET:-}" -H "Content-Type: application/json" --max-time 30
EOF
    crond -f -L /dev/stdout -c "${SPOOL_DIR}" &
  fi
fi

exec /usr/local/bin/docker-startup.sh "$@"
