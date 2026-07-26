#!/usr/bin/env sh
set -eu

# Rootless notification cron.
# Replaces the upstream image's setuid `crontab` + Alpine `dcron` setup, which
# cannot run as a non-root user. We write a crontab for the runtime user and
# launch busybox `crond` (which runs fine unprivileged) in the background.
#
# Active only when ENABLE_NOTIFICATIONS=true. The app's /api/notifications/cron
# endpoint is itself gated by a DB flag, so firing when notifications are
# disabled at the app level is a harmless no-op. The spool dir must be writable
# (mount it as an emptyDir/tmpfs when using a read-only root filesystem).
if [ "${ENABLE_NOTIFICATIONS:-false}" = "true" ]; then
  SPOOL_DIR="/var/spool/cron/crontabs"
  mkdir -p "${SPOOL_DIR}"
  CRON_USER="$(id -un)"
  cat > "${SPOOL_DIR}/${CRON_USER}" <<EOF
* * * * * curl -fsS -X POST http://localhost:3000/api/notifications/cron -H "Authorization: Bearer ${NOTIFICATION_CRON_SECRET:-}" -H "Content-Type: application/json" --max-time 30
EOF
  crond -f -L /dev/stdout -c "${SPOOL_DIR}" &
fi

exec /usr/local/bin/docker-startup.sh "$@"
