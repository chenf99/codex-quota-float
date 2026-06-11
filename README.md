# Codex Quota Float

Codex Quota Float is a macOS floating window and CLI for local Codex quota
buckets. It reads the Codex account configured on your machine.

## Install CLI

```bash
curl -fsSL https://raw.githubusercontent.com/chenf99/codex-quota-float/main/install.sh | zsh
```

This installs the repository under `~/.local/share/codex-quota-float` and adds
`codex-quota-float` to `~/.local/bin`.

After that, `codex-quota-float` works from any directory:

```bash
codex-quota-float start
codex-quota-float status
codex-quota-float skin set ~/Pictures/skin.png "My Skin"
codex-quota-float login install
codex-quota-float stop
codex-quota-float update
```

If `~/.local/bin` is not in your shell `PATH`, the installer prints the line to
add.

## Optional Codex Plugin

You do not need the Codex plugin to use the floating quota window. Install the
plugin only if you also want Codex to know these workflows as an installed
skill.

```bash
codex plugin marketplace add chenf99/codex-quota-float --ref main
codex plugin add codex-quota-float@codex-quota-float
```

Installing the plugin only makes it available to Codex. It does not
automatically start the floating window. Start it by asking Codex:

```text
Open the Codex quota floating window.
```

## macOS Only

This plugin currently uses Swift and AppKit (`NSWindow`, `.app` bundles,
`launchctl`, and `sips`). Windows and Linux are not supported by this version.

## Personal Skins

The public plugin does not include personal images. Users can configure their
own local image skin:

```bash
codex-quota-float skin set /path/to/image.png "My Skin Name"
```

The image is copied to `~/.codex-quota-float/skins/`, outside this repository.
