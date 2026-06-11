# Codex Quota Float Marketplace

This repository is a Codex plugin marketplace for `codex-quota-float`, a
macOS floating window that shows local Codex quota buckets.

## Install

```bash
codex plugin marketplace add chenf99/codex-quota-float --ref main
codex plugin add codex-quota-float@codex-quota-float
```

Installing the plugin only makes it available to Codex. It does not
automatically start the floating window.

Start it by asking Codex:

```text
Open the Codex quota floating window.
```

Or install the command-line wrapper once:

```text
Install the Codex Quota Float CLI.
```

After that, `codex-quota-float` works from any directory:

```bash
codex-quota-float start
codex-quota-float status
codex-quota-float skin set ~/Pictures/skin.png "My Skin"
codex-quota-float login install
codex-quota-float stop
```

For automatic startup after login without installing the CLI, ask Codex:

```text
Install Codex Quota Float as a login item.
```

## macOS Only

This plugin currently uses Swift and AppKit (`NSWindow`, `.app` bundles,
`launchctl`, and `sips`). Windows and Linux are not supported by this version.

## Personal Skins

The public plugin does not include personal images. Users can configure their
own local image skin after installing the CLI:

```bash
codex-quota-float skin set /path/to/image.png "My Skin Name"
```

The image is copied to `~/.codex-quota-float/skins/`, outside this repository.
