#!/usr/bin/env sh
set -eu

# Rootless notification cron.
# Replaces the upstream image's setuid `crontab` + Alpine `dcron` setup, which
# cannot run as a non-root user. We write a crontab for the runtime user and
# launch busybox `crond` (which runs fine unprivileged) in the background.
#
# Active only when ENABLE_NOTIFICATIONS=true. The app's /api/notifications/cron
# endpoint is itself gated by a DB flag, so firing when notifications are
# disabled at the app level is a harmless no-op.
#
# The crontab spool (/var/spool/cron) MUST be writable — under a read-only root
# filesystem, mount it as an emptyDir/tmpfs. If it is not writable we skip the
# in-pod cron (the app still starts) and warn on stderr rather than crashing.
if [ "${ENABLE_NOTIFICATIONS:-false}" = "true" ]; then
  SPOOL_DIR="/var/spool/cron/crontabs"
  if ! mkdir -p "${SPOOL_DIR}" 2>/dev/null || ! [ -w "${SPOOL_DIR}" ]; then
    echo "entrypoint: ENABLE_NOTIFICATIONS=true but ${SPOOL_DIR} is not writable; skipping in-pod cron. Mount /var/spool/cron as an emptyDir/tmpfs (read-only root fs)." >&2
  else
    CRON_USER="$(id -un)"
    cat > "${SPOOL_DIR}/${CRON_USER}" <<EOF
* * * * * curl -fsS -X POST http://localhost:3000/api/notifications/cron -H "Authorization: Bearer ${NOTIFICATION_CRON_SECRET:-}" -H "Content-Type: application/json" --max-time 30
EOF
    crond -f -L /dev/stdout -c "${SPOOL_DIR}" &
  fi
fi

exec /usr/local/bin/docker-startup.sh "$@"
