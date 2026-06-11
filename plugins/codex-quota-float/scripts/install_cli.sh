#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: install_cli.sh [target-directory-or-path]

Installs a codex-quota-float command that works from any directory.

Default target:
  ~/.local/bin/codex-quota-float

Examples:
  scripts/install_cli.sh
  scripts/install_cli.sh /usr/local/bin/codex-quota-float
  scripts/install_cli.sh ~/.local/bin/
USAGE
  exit 0
fi

TARGET_ARG="${1:-${CODEX_QUOTA_CLI_DIR:-$HOME/.local/bin}}"

if [[ "$TARGET_ARG" == */ || -d "$TARGET_ARG" || "${TARGET_ARG:t}" != "codex-quota-float" ]]; then
  TARGET_DIR="$TARGET_ARG"
  TARGET_NAME="codex-quota-float"
else
  TARGET_DIR="${TARGET_ARG:h}"
  TARGET_NAME="${TARGET_ARG:t}"
fi

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
TARGET_PATH="$TARGET_DIR/$TARGET_NAME"
QUOTED_PLUGIN_ROOT="${(q)PLUGIN_ROOT}"

cat > "$TARGET_PATH" <<WRAPPER
#!/usr/bin/env zsh
set -euo pipefail
PLUGIN_ROOT=$QUOTED_PLUGIN_ROOT
exec "\$PLUGIN_ROOT/scripts/codex-quota-float" "\$@"
WRAPPER

chmod +x "$TARGET_PATH"

echo "Installed CLI: $TARGET_PATH"
if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
  echo
  echo "Add this directory to PATH to run it from any terminal:"
  echo "  export PATH=\"$TARGET_DIR:\$PATH\""
fi
