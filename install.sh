#!/usr/bin/env zsh
set -euo pipefail

REPO_URL="${CODEX_QUOTA_REPO_URL:-https://github.com/chenf99/codex-quota-float.git}"
REF="${CODEX_QUOTA_REF:-main}"
INSTALL_DIR="${CODEX_QUOTA_INSTALL_DIR:-$HOME/.local/share/codex-quota-float}"
BIN_DIR="${CODEX_QUOTA_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${CODEX_QUOTA_CONFIG_DIR:-$HOME/.codex-quota-float}"
TELEMETRY_BASE_URL="${CODEX_QUOTA_TELEMETRY_BASE_URL:-https://countapi.mileshilliard.com/api/v1}"
TELEMETRY_KEY_PREFIX="${CODEX_QUOTA_TELEMETRY_KEY_PREFIX:-chenf99-codex-quota-float}"
TELEMETRY_DISABLED_FILE="$CONFIG_DIR/telemetry.disabled"
INSTALL_COUNTED_FILE="$CONFIG_DIR/install-counted"

print_usage() {
  cat <<'USAGE'
Usage: install.sh

Installs or updates Codex Quota Float as a standalone macOS CLI.

Environment overrides:
  CODEX_QUOTA_REPO_URL      Git repository URL.
  CODEX_QUOTA_REF           Git ref to install. Defaults to main.
  CODEX_QUOTA_INSTALL_DIR   Install directory. Defaults to ~/.local/share/codex-quota-float.
  CODEX_QUOTA_BIN_DIR       CLI directory. Defaults to ~/.local/bin.
  CODEX_QUOTA_TELEMETRY=0   Disable the anonymous install counter.

After installation:
  codex-quota-float start
  codex-quota-float status
  codex-quota-float stats
  codex-quota-float autostart install

For a custom image skin, right-click the floating window and choose:
  Skin -> Choose Image...
USAGE
}

telemetry_disabled() {
  case "${CODEX_QUOTA_TELEMETRY:-}" in
    0|false|FALSE|off|OFF|no|NO)
      return 0
      ;;
  esac

  [[ -f "$TELEMETRY_DISABLED_FILE" ]]
}

telemetry_key() {
  local event="$1"
  echo "${TELEMETRY_KEY_PREFIX}-${event}"
}

telemetry_url() {
  local action="$1"
  local event="$2"
  echo "${TELEMETRY_BASE_URL%/}/$action/$(telemetry_key "$event")"
}

record_install_count_once() {
  if telemetry_disabled; then
    return 0
  fi

  if [[ -f "$INSTALL_COUNTED_FILE" ]]; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "$CONFIG_DIR" 2>/dev/null || return 0

  if curl -fsS --max-time 3 -o /dev/null "$(telemetry_url hit install)" 2>/dev/null; then
    {
      echo "counted_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      echo "event=install"
    } >"$INSTALL_COUNTED_FILE" 2>/dev/null || true
  fi
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  print_usage
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Codex Quota Float currently supports macOS only." >&2
  exit 2
fi

cleanup_tmp() {
  if [[ -n "${TMP_INSTALL_DIR:-}" && -d "$TMP_INSTALL_DIR" ]]; then
    rm -rf "$TMP_INSTALL_DIR"
  fi
}
trap cleanup_tmp EXIT

install_with_git() {
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  mkdir -p "${INSTALL_DIR:h}"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL"
    git -C "$INSTALL_DIR" fetch --depth 1 origin "$REF"
    git -C "$INSTALL_DIR" checkout --detach FETCH_HEAD
    return 0
  fi

  TMP_INSTALL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-quota-float.XXXXXX")"
  git -c init.templateDir= init -q "$TMP_INSTALL_DIR"
  git -C "$TMP_INSTALL_DIR" remote add origin "$REPO_URL"
  git -C "$TMP_INSTALL_DIR" fetch --depth 1 origin "$REF"
  git -C "$TMP_INSTALL_DIR" checkout -q --detach FETCH_HEAD

  rm -rf "$INSTALL_DIR"
  mv "$TMP_INSTALL_DIR" "$INSTALL_DIR"
  unset TMP_INSTALL_DIR
}

install_with_archive() {
  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    return 1
  fi

  local archive_url
  archive_url="${CODEX_QUOTA_ARCHIVE_URL:-https://codeload.github.com/chenf99/codex-quota-float/tar.gz/$REF}"

  mkdir -p "${INSTALL_DIR:h}"
  TMP_INSTALL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-quota-float.XXXXXX")"
  curl -fsSL "$archive_url" | tar -xz -C "$TMP_INSTALL_DIR" --strip-components 1

  rm -rf "$INSTALL_DIR"
  mv "$TMP_INSTALL_DIR" "$INSTALL_DIR"
  unset TMP_INSTALL_DIR
}

echo "Installing Codex Quota Float..."
echo "  ref: $REF"
echo "  install dir: $INSTALL_DIR"
echo "  bin dir: $BIN_DIR"

if ! install_with_git; then
  echo "git is unavailable; falling back to GitHub archive download."
  install_with_archive
fi

if [[ ! -x "$INSTALL_DIR/scripts/install_cli.sh" ]]; then
  echo "Installed repository is missing the CLI installer: $INSTALL_DIR/scripts/install_cli.sh" >&2
  exit 1
fi

"$INSTALL_DIR/scripts/install_cli.sh" "$BIN_DIR"
record_install_count_once

echo
echo "Codex Quota Float is installed."
echo "Try:"
echo "  codex-quota-float start"
echo "  codex-quota-float status"
echo "  codex-quota-float stats"
echo "  codex-quota-float autostart install"
echo
if telemetry_disabled; then
  echo "Anonymous install counting is disabled on this machine."
else
  echo "Anonymous install counting is enabled. It sends only an install event name."
  echo "Disable it with: codex-quota-float telemetry disable"
fi
echo
echo "For a custom image skin, right-click the floating window and choose:"
echo "  Skin -> Choose Image..."
