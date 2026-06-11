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
codex-quota-float autostart install
codex-quota-float stop
codex-quota-float update
```

Right-click the floating ball or expanded panel for refresh, skin switching,
and quit.

## Command Reference

```bash
codex-quota-float start [--interval seconds] [--normal-window]
```

Opens the floating window. It builds the local `.app` bundle on first run and
uses a 60-second refresh interval by default.

```bash
codex-quota-float stop
```

Quits the floating window started from this install.

```bash
codex-quota-float restart [--interval seconds] [--normal-window]
```

Stops and reopens the floating window.

```bash
codex-quota-float status [--pretty|--json]
```

Prints a one-shot quota summary by reading the local Codex app-server account
and rate-limit snapshot.

```bash
codex-quota-float skin set <image-path> [skin-title]
```

Copies a local image to `~/.codex-quota-float/skins/` and uses it as the ball
and panel skin. The optional title is shown in the skin menu.

```bash
codex-quota-float skin reset
```

Removes the custom skin config and returns to `Classic Glass`.

```bash
codex-quota-float skin path
```

Prints the user-local skin config path and current config, if one exists.

```bash
codex-quota-float autostart install
```

Creates `~/Library/LaunchAgents/local.codex-quota-float.plist`, loads it with
`launchctl`, and starts the app now. This makes the app open automatically after
macOS user login.

```bash
codex-quota-float autostart uninstall
```

Unloads and removes the LaunchAgent so the app no longer starts after login.

```bash
codex-quota-float update
```

Updates the installed repository from GitHub and refreshes the CLI wrapper.

```bash
codex-quota-float path
```

Prints the install directory, usually `~/.local/share/codex-quota-float`.

```bash
codex-quota-float cli install [target-directory-or-path]
```

Reinstalls the shell wrapper. This is mostly useful if you want a different
binary directory than `~/.local/bin`.

`open`, `quit`, `upgrade`, and `login install/uninstall` are compatibility
aliases for `start`, `stop`, `update`, and `autostart install/uninstall`.

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
