#!/usr/bin/env sh
set -eu

# Create the single writable region every symlinked ephemeral path resolves into
# (the mounted /tmp emptyDir). The baked symlinks in the image point here.
mkdir -p /tmp/bedrock/env /tmp/bedrock/logs /tmp/bedrock/prisma-client /tmp/bedrock/cron/crontabs

# TODO: app-specific setup (env bootstrap, cron, etc.).

exec <APP_START_COMMAND> "$@"
