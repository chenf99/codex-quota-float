# Codex Quota Float

Codex Quota Float is a macOS floating window and CLI for local Codex quota
buckets. It reads the Codex account configured on your machine and shows the
current rate-limit buckets in a small always-on-top window.

## Install

```bash
curl -fsSL "https://raw.githubusercontent.com/chenf99/codex-quota-float/main/install.sh?$(date +%s)" | zsh
```

This installs the repository under `~/.local/share/codex-quota-float` and adds
`codex-quota-float` to `~/.local/bin`. If `~/.local/bin` is not in your shell
`PATH`, the installer prints the line to add.

## Usage

```bash
codex-quota-float start
codex-quota-float status
codex-quota-float skin set ~/Pictures/skin.png "My Skin"
codex-quota-float login install
codex-quota-float stop
codex-quota-float update
```

Right-click the floating ball or expanded panel for refresh, skin switching,
and quit.

## Personal Skins

The public repository does not include personal images. Configure your own
local image skin:

```bash
codex-quota-float skin set /path/to/image.png "My Skin Name"
```

The image is copied to `~/.codex-quota-float/skins/`, outside this repository.
Without a configured image skin, the app uses `Classic Glass`.

## macOS Only

This tool currently uses Swift and AppKit (`NSWindow`, `.app` bundles,
`launchctl`, and `sips`). Windows and Linux are not supported by this version.

## Development

Run directly from the repository:

```bash
scripts/codex-quota-float start
scripts/codex-quota-float status
```

Build artifacts live under `.build/` and `dist/`.
