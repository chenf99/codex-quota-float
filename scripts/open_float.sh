#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$("$SCRIPT_DIR/make_app_bundle.sh")"

/usr/bin/open -n "$APP_PATH" --args "$@"
echo "Opened $APP_PATH"
