# Codex Quota Float

A local macOS floating window for Codex quota buckets. It reads quota snapshots
from the local Codex app-server and refreshes every 60 seconds by default.

## Run

For terminal usage, install the CLI once:

```bash
scripts/codex-quota-float cli install
```

Then run from any directory:

```bash
codex-quota-float start
codex-quota-float status
codex-quota-float stop
```

Use right-click on the floating ball or panel for refresh, skin switching, and
quit. Direct script usage is still available from this plugin root:

```bash
scripts/open_float.sh
```

For standalone installs that do not need the Codex plugin, use the repository
installer instead:

```bash
curl -fsSL https://raw.githubusercontent.com/chenf99/codex-quota-float/main/install.sh | zsh
```

## Custom Image Skin

Set a local image as the panel and ball skin:

```bash
codex-quota-float skin set /path/to/image.png "My Skin Name"
codex-quota-float restart
```

The setup script writes user-local config to `~/.codex-quota-float/config.env`
and copies the image to `~/.codex-quota-float/skins/`. Personal images are not
part of the plugin source.

Without a configured image skin, the plugin falls back to `Classic Glass`.

## Per-User Behavior

The quota collector runs `codex app-server --listen stdio://` locally and reads
the Codex account configured on that machine. It does not include a hard-coded
account or shared token. Image skin config is also user-local under
`~/.codex-quota-float/`.

## Community Packaging

For public distribution, keep this plugin free of personal assets:

- Do not commit files under `assets/*.png`, `assets/*.jpg`, `assets/*.jpeg`, or
  `assets/*.webp`.
- Keep user-specific skins in `~/.codex-quota-float/skins/`.
- Prefer the root `install.sh` path for public CLI distribution.
- Keep the Git marketplace path as optional Codex skill integration.
