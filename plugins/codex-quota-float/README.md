# Codex Quota Float

A local macOS floating window for Codex quota buckets. It reads quota snapshots
from the local Codex app-server and refreshes every 60 seconds by default.

## Run

```bash
scripts/open_float.sh
```

Use right-click on the floating ball or panel for refresh, skin switching, and
quit.

## Custom Image Skin

Set a local image as the panel and ball skin:

```bash
scripts/set_image_skin.sh /path/to/image.png "My Skin Name"
scripts/open_float.sh
```

The setup script writes user-local config to `~/.codex-quota-float/config.env`
and copies the image to `~/.codex-quota-float/skins/`. Personal images are not
part of the plugin source.

Without a configured image skin, the plugin falls back to `Classic Glass`.

## Community Packaging

For public distribution, keep this plugin free of personal assets:

- Do not commit files under `assets/*.png`, `assets/*.jpg`, `assets/*.jpeg`, or
  `assets/*.webp`.
- Keep user-specific skins in `~/.codex-quota-float/skins/`.
- Distribute the plugin through a Git marketplace repository so users can run
  `codex plugin marketplace add <owner/repo>` and then
  `codex plugin add codex-quota-float@<marketplace>`.
