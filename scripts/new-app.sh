#!/usr/bin/env sh
# Scaffold a new app from templates/app.
# Usage: scripts/new-app.sh <app-name>
set -eu

APP="${1:-}"
if [ -z "$APP" ]; then
  echo "Usage: scripts/new-app.sh <app-name>" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SRC="$ROOT/templates/app"
DST="$ROOT/apps/$APP"

if [ -d "$DST" ]; then
  echo "apps/$APP already exists" >&2
  exit 1
fi
if [ ! -d "$SRC" ]; then
  echo "template not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DST"
cp "$SRC"/Dockerfile "$SRC"/docker-bake.hcl "$SRC"/entrypoint.sh "$SRC"/.dockerignore "$SRC"/README.md "$SRC"/.grype.yaml "$SRC"/SECURITY.md.tmpl "$DST"/
chmod +x "$DST/entrypoint.sh"

# Substitute the app name into the scaffolded files (portable sed -i).
for f in "$DST"/Dockerfile "$DST"/docker-bake.hcl "$DST"/entrypoint.sh "$DST"/README.md "$DST"/.grype.yaml "$DST"/SECURITY.md.tmpl; do
  sed -i.bak "s/<app>/$APP/g; s/<APP>/$APP/g" "$f" && rm -f "$f.bak"
done

# Best-effort: generate the initial SECURITY.md from the template.
if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/scripts/gen-security-md.py" "$DST" || true
fi

echo "Created apps/$APP from templates/app."
echo
echo "Next: edit the remaining placeholders (search for '<'):"
echo "  <UPSTREAM_*>         upstream image / version / source"
echo "  <APP_START_COMMAND>  CMD / exec target"
echo "  .grype.yaml           list accepted vulns (start empty); SECURITY.md is generated"
echo "  Adjust the baked /tmp/bedrock symlinks in the Dockerfile to the paths your app writes."
echo
echo "Files:"
ls -la "$DST"
