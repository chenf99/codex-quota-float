#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$INSTALL_ROOT/.build"
SWIFT_SRC="$SCRIPT_DIR/QuotaFloat.swift"
BIN="$BUILD_DIR/codex-quota-float"
STATUS_SCRIPT="$SCRIPT_DIR/codex_quota_status.py"
BUILD_ONLY=0

case "${1:-}" in
  --help|-h)
    cat <<'USAGE'
Usage: run_float.sh [--interval seconds] [--normal-window]
       run_float.sh --build-only
       run_float.sh --open

Starts the Codex quota floating window. The window refreshes every 60 seconds
unless --interval is provided.
USAGE
    exit 0
    ;;
  --open)
    exec "$SCRIPT_DIR/open_float.sh"
    ;;
  --build-only)
    BUILD_ONLY=1
    shift
    ;;
esac

mkdir -p "$BUILD_DIR"

if [[ ! -x "$BIN" || "$SWIFT_SRC" -nt "$BIN" ]]; then
  swiftc -O -framework AppKit -o "$BIN" "$SWIFT_SRC"
fi

if [[ "$BUILD_ONLY" == "1" ]]; then
  echo "$BIN"
  exit 0
fi

CONFIG_DIR="${CODEX_QUOTA_CONFIG_DIR:-$HOME/.codex-quota-float}"
CONFIG_FILE="$CONFIG_DIR/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

DEFAULT_AVATAR_IMAGE="$INSTALL_ROOT/assets/image.png"
AVATAR_IMAGE="${CODEX_QUOTA_SKIN_IMAGE:-$DEFAULT_AVATAR_IMAGE}"
IMAGE_SKIN_TITLE="${CODEX_QUOTA_SKIN_TITLE:-Image Skin}"
AVATAR_INITIALS="${CODEX_QUOTA_AVATAR_INITIALS:-CF}"

skin_args=()
if [[ -f "$AVATAR_IMAGE" ]]; then
  skin_args=(--avatar-image "$AVATAR_IMAGE" --skin image --avatar-initials "$AVATAR_INITIALS" --image-skin-title "$IMAGE_SKIN_TITLE")
else
  skin_args=(--skin classic)
fi

exec "$BIN" --status-script "$STATUS_SCRIPT" "${skin_args[@]}" "$@"
