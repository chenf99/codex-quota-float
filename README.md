# Codex Quota Float Marketplace

This repository is a Codex plugin marketplace for `codex-quota-float`, a
macOS floating window that shows local Codex quota buckets.

## Install

```bash
codex plugin marketplace add chenf99/codex-quota-float --ref main
codex plugin add codex-quota-float@codex-quota-float
```

Installing the plugin does not automatically start the floating window. Start it
by asking Codex:

```text
Open the Codex quota floating window.
```

For automatic startup after login, ask Codex:

```text
Install Codex Quota Float as a login item.
```

## macOS Only

This plugin currently uses Swift and AppKit (`NSWindow`, `.app` bundles,
`launchctl`, and `sips`). Windows and Linux are not supported by this version.

## Personal Skins

The public plugin does not include personal images. Users can configure their
own local image skin:

```bash
scripts/set_image_skin.sh /path/to/image.png "My Skin Name"
```

The image is copied to `~/.codex-quota-float/skins/`, outside this repository.
