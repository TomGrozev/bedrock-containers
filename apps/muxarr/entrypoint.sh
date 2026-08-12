#!/usr/bin/env sh
set -eu

# HOME (see Dockerfile ENV) points here for ASP.NET Core's Data Protection key ring.
# Ephemeral only -- keys are not persisted across restarts (auth cookies/sessions reset
# on redeploy), a known trade-off documented in README.md.
mkdir -p /tmp/bedrock/home

exec "$@"
