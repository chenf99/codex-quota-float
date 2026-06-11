---
name: codex-quota-float
description: Start or inspect a local macOS floating window that shows Codex app-server rate-limit buckets and remaining quota percentages.
---

# Codex Quota Float

Use this skill when the user asks to view Codex quota, remaining quota, rate limits, or the Codex quota floating window.

Resolve the plugin root as two directories above this `SKILL.md` before running
scripts. Installing the plugin does not start the floating window by itself.
Prefer `scripts/codex-quota-float` for user-facing operations because it
provides stable start, stop, status, skin, login-item, and CLI-install commands.

## Commands

- Start the floating window:

```bash
scripts/codex-quota-float start
```

- Start it in the current terminal instead:

```bash
scripts/run_float.sh
```

- In the floating window, right-click the ball or detail panel for `Refresh Now`, `Skin`, and `Quit Codex Quota`.
- Install a shell command that works from any directory:

```bash
scripts/codex-quota-float cli install
```

- Users can set their own image skin without editing source:

```bash
scripts/codex-quota-float skin set /path/to/image.png "My Skin Name"
```

- Pass `--image-skin-title "<name>"` with `--avatar-image <path>` when launching with a one-off custom image.
- If no image skin is configured, the plugin starts with `Classic Glass`.
- Quota and image skin config are per-user. The collector reads the local Codex
  app-server account, and custom image skins live under `~/.codex-quota-float/`.

- Print a one-shot terminal summary:

```bash
scripts/codex-quota-float status
```

- Print raw JSON:

```bash
scripts/codex-quota-float status --pretty
```

- Install as a login item:

```bash
scripts/codex-quota-float login install
```

- Remove the login item:

```bash
scripts/codex-quota-float login uninstall
```

## Notes

- The collector talks to `codex app-server --listen stdio://` and sends `account/read` plus `account/rateLimits/read`.
- The local daemon path may be unavailable on app-bundled installs; this plugin does not require the daemon and can short-run app-server for each refresh.
- The window refreshes every 60 seconds by default. Pass `--interval <seconds>` to change it.
