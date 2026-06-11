# Codex Quota Float Marketplace

This repository is a Codex plugin marketplace for `codex-quota-float`, a
macOS floating window that shows local Codex quota buckets.

## Install

```bash
codex plugin marketplace add <owner>/codex-quota-float --ref main
codex plugin add codex-quota-float@codex-quota-float
```

Then ask Codex to open the floating quota window, or run the plugin scripts
from the installed plugin root.

## macOS Only

This plugin currently uses Swift and AppKit (`NSWindow`, `.app` bundles,
`launchctl`, and `sips`). Windows and Linux are not supported by this version.

## Personal Skins

The public plugin does not include personal images. Users can configure their
own local image skin:

```bash
plugins/codex-quota-float/scripts/set_image_skin.sh /path/to/image.png "My Skin Name"
```

The image is copied to `~/.codex-quota-float/skins/`, outside this repository.
