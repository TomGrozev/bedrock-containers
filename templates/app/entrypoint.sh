#!/usr/bin/env sh
set -eu

# Entrypoint for the hardened <APP> image.
# - runs as a non-root user (65532:65532); never rely on setuid or root-only ops
# - all writes go to declared writable mounts (see apps/<APP>/README.md)
# - under a read-only root filesystem, degrade gracefully if a required writable
#   path is missing: warn on stderr and continue rather than crash

# TODO: app-specific setup (env bootstrap, cron, etc.).

exec <APP_START_COMMAND> "$@"
