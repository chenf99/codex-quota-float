#!/usr/bin/env zsh
set -euo pipefail

LABEL="local.codex-quota-float.auto-update"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "Automatic updates are disabled."
echo "Removed $PLIST"
