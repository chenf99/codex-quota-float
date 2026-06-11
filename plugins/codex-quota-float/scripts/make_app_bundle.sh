#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_ROOT="$PLUGIN_ROOT/dist/Codex Quota Float.app"
CONTENTS="$APP_ROOT/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BIN="$MACOS/codex-quota-float-bin"
LAUNCHER="$MACOS/codex-quota-float"

mkdir -p "$MACOS" "$RESOURCES"

swiftc -O -framework AppKit -o "$BIN" "$SCRIPT_DIR/QuotaFloat.swift"

cat > "$LAUNCHER" <<LAUNCHER
#!/usr/bin/env zsh
set -euo pipefail
CONFIG_DIR="\${CODEX_QUOTA_CONFIG_DIR:-\$HOME/.codex-quota-float}"
CONFIG_FILE="\$CONFIG_DIR/config.env"
if [[ -f "\$CONFIG_FILE" ]]; then
  source "\$CONFIG_FILE"
fi

DEFAULT_AVATAR_IMAGE="$PLUGIN_ROOT/assets/image.png"
AVATAR_IMAGE="\${CODEX_QUOTA_SKIN_IMAGE:-\$DEFAULT_AVATAR_IMAGE}"
IMAGE_SKIN_TITLE="\${CODEX_QUOTA_SKIN_TITLE:-Image Skin}"
AVATAR_INITIALS="\${CODEX_QUOTA_AVATAR_INITIALS:-CF}"

skin_args=()
if [[ -f "\$AVATAR_IMAGE" ]]; then
  skin_args=(--avatar-image "\$AVATAR_IMAGE" --skin image --avatar-initials "\$AVATAR_INITIALS" --image-skin-title "\$IMAGE_SKIN_TITLE")
else
  skin_args=(--skin classic)
fi

exec "$BIN" --status-script "$PLUGIN_ROOT/scripts/codex_quota_status.py" "\${skin_args[@]}" "\$@"
LAUNCHER
chmod +x "$LAUNCHER"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>codex-quota-float</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex-quota-float</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Quota Float</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_ROOT"
