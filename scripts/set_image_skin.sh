#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -lt 1 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: set_image_skin.sh <image-path> [skin-title]

Copies a local image into the Codex Quota Float user config directory and
uses it as the image skin. If skin-title is omitted, the image filename is
used as the menu title.
USAGE
  exit 0
fi

SOURCE_IMAGE="$1"
if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Image not found: $SOURCE_IMAGE" >&2
  exit 2
fi

CONFIG_DIR="${CODEX_QUOTA_CONFIG_DIR:-$HOME/.codex-quota-float}"
SKIN_DIR="$CONFIG_DIR/skins"
CONFIG_FILE="$CONFIG_DIR/config.env"
mkdir -p "$SKIN_DIR"

SKIN_IMAGE="$SKIN_DIR/custom-image-skin.png"
if command -v sips >/dev/null 2>&1; then
  sips -s format png "$SOURCE_IMAGE" --out "$SKIN_IMAGE" >/dev/null
else
  cp "$SOURCE_IMAGE" "$SKIN_IMAGE"
fi

if [[ $# -ge 2 && -n "${2:-}" ]]; then
  SKIN_TITLE="$2"
else
  BASE_NAME="${SOURCE_IMAGE:t:r}"
  SKIN_TITLE="${BASE_NAME//[-_]/ }"
fi

{
  printf 'export CODEX_QUOTA_SKIN_IMAGE=%q\n' "$SKIN_IMAGE"
  printf 'export CODEX_QUOTA_SKIN_TITLE=%q\n' "$SKIN_TITLE"
} > "$CONFIG_FILE"

echo "Configured image skin:"
echo "  image: $SKIN_IMAGE"
echo "  title: $SKIN_TITLE"
