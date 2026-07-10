#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LABEL="local.codex-quota-float.auto-update"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/CodexQuotaFloat"
INTERVAL_SECONDS="${CODEX_QUOTA_AUTO_UPDATE_INTERVAL:-21600}"

if [[ ! "$INTERVAL_SECONDS" =~ '^[0-9]+$' || "$INTERVAL_SECONDS" -lt 300 ]]; then
  echo "CODEX_QUOTA_AUTO_UPDATE_INTERVAL must be an integer of at least 300 seconds." >&2
  exit 2
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALL_ROOT/scripts/codex-quota-float</string>
    <string>auto-update</string>
    <string>check</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>$INTERVAL_SECONDS</integer>
  <key>ProcessType</key>
  <string>Background</string>
  <key>LowPriorityIO</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/auto-update.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/auto-update.error.log</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Automatic updates are enabled (every $((INTERVAL_SECONDS / 3600)) hours)."
echo "Installed $PLIST"
