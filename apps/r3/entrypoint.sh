#!/usr/bin/env sh
set -eu

# Create the single writable region every ephemeral XDG path resolves into (the
# mounted /tmp emptyDir). The persistent state dir (/data) is mounted separately.
mkdir -p /tmp/bedrock/runtime /tmp/bedrock/config /tmp/bedrock/home /tmp/bedrock/tmp
chmod 0700 /tmp/bedrock/runtime   # XDG_RUNTIME_DIR must be 0700

# Run the hidden `__daemon` subcommand in the FOREGROUND so PID 1 (tini) supervises
# the server and forwards SIGTERM for a graceful shutdown. `r3 server start` daemonizes
# (double-forks), which would leave PID 1 with nothing to supervise.
exec /app/r3 __daemon "$@"
