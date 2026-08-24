# openlogi-herdr

[![CI](https://github.com/giacolees/herdr-openlogi/actions/workflows/ci.yml/badge.svg)](https://github.com/giacolees/herdr-openlogi/actions/workflows/ci.yml)

Canonizes the ad-hoc integration between [OpenLogi](https://github.com/openlogi/openlogi) (Logitech mouse driver) and [herdr](https://herdr.dev) (terminal workspace manager): Logitech mouse buttons and gestures drive herdr pane/tab actions, but only while the host terminal — [Ghostty](https://ghostty.org) — is focused.

The **Binding overlay** in OpenLogi gates every action (no script runs unless Ghostty is frontmost); a single **Dispatcher** (`bin/herdr-mouse`) translates each input into a herdr socket-API call; every failure is a **Silent no-op**.

This repo is the versioned source of truth for the dispatcher script, its symlink deployment, and the OpenLogi binding overlay it depends on. It never patches OpenLogi or herdr, never auto-edits OpenLogi's app-managed config, and never adds new herdr features.

---

## Prerequisites

| Requirement | Notes |
| --- | --- |
| **macOS** | OpenLogi and Ghostty are macOS apps. |
| **OpenLogi** | Installed and launched at least once (so `~/.config/openlogi/config.toml` exists). |
| **Ghostty** | Bundle ID `com.mitchellh.ghostty` — the host app for the overlay. |
| **Logitech mouse** | Tested with `direct:046d:b034` (MX Master 3S). Any OpenLogi-supported mouse works; your device key will differ. |
| **herdr** | In `PATH` at `~/.local/bin/herdr`, `/opt/homebrew/bin/herdr`, or `/usr/local/bin/herdr`. Verify with `herdr status`. Requires `>= 0.7.0` for the plugin path. |
| **`jq`** | Used by tab-cycle logic to parse `herdr tab list` JSON. Install via `brew install jq`. Verify with `jq --version`. |
| **POSIX `sh`** | No other runtime deps. Scripts are ShellCheck-clean. |

---

## Compatibility

| Component | Version / Requirement |
| --- | --- |
| **macOS** | macOS 13+ |
| **OpenLogi** | OpenLogi latest |
| **Ghostty** | `com.mitchellh.ghostty` (bundle ID) — Ghostty `com.mitchellh.ghostty` |
| **herdr** | herdr latest (`>= 0.7.0` for `herdr plugin install`) |
| **Mouse** | MX Master 3S (any OpenLogi-supported mouse works) |

---

## Install

### Recommended: herdr plugin

```sh
herdr plugin install giacolees/herdr-openlogi
```

This is the primary install path. herdr validates the Plugin manifest (`herdr-plugin.toml`), registers nine actions (one per Dispatcher subcommand), and runs the Bootstrap startup hook once after session restore.

The Bootstrap hook (`scripts/bootstrap.sh` via `[[startup]]` in `herdr-plugin.toml`) idempotently creates the symlink the Binding overlay calls:

```
~/.local/bin/herdr-mouse → $HERDR_PLUGIN_ROOT/bin/herdr-mouse
```

Re-installing or updating the plugin retargets the symlink automatically. No manual `install.sh` step is needed for the symlink.

Verify the deployment:

```sh
herdr plugin action list --plugin openlogi.herdr-mouse  # lists the nine actions
~/.local/bin/herdr-mouse focus-right  # should exit 0, no output if herdr is not running
./install.sh --check                # overlay + symlink health (symlink owned by Bootstrap)
```

> **Marketplace:** the plugin is listable on <https://herdr.dev/plugins/> once the repository owner adds the `herdr-plugin` GitHub topic to `giacolees/herdr-openlogi` at release (index refresh ≤ 30 min).

You still need to add the OpenLogi Binding overlay once (next section) — the plugin does not auto-edit OpenLogi's app-managed config.

### Add the OpenLogi binding overlay

OpenLogi's per-app overlay lives in `~/.config/openlogi/config.toml` under a device-keyed table. You must add it by hand — neither `herdr plugin install` nor `install.sh` edits this file without `--apply`.

**a. Find your device key:**

```sh
grep selected_device ~/.config/openlogi/config.toml
# e.g. selected_device = "direct:046d:b034:serial:2419lz522j28"
```

The device key is that quoted string (the part after `selected_device =`).

**b. Open the config:**

```sh
open ~/.config/openlogi/config.toml   # or $EDITOR ~/.config/openlogi/config.toml
```

**c. Paste the overlay block** under that device. The canonical snippet is in [`openlogi/per-app-bindings.toml`](openlogi/per-app-bindings.toml) — copy it verbatim:

```toml
[devices."direct:046d:b034:serial:2419lz522j28".per_app_bindings."com.mitchellh.ghostty"]
Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }
Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }
GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }
DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }
ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }
ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }

# Gesture pad directions (add if your device exposes them and you want up/down focus):
# GestureUp   = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }
# GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }
```

**Important:** replace `direct:046d:b034:serial:2419lz522j28` in the header with your own device key from step (a), but leave the four `RunShellCommand` lines exactly as shown (with a space between `herdr-mouse` and the subcommand — the legacy slash form `herdr-mouse/focus-left` will be flagged as wrong). The literal string `$HOME` is intentional — OpenLogi expands it; do not substitute your home path.

> The commented `GestureUp`/`GestureDown` lines are optional. Uncomment them only if your device exposes gesture-pad directions and you want vertical pane focus.

#### Automated alternative (opt-in)

Manual paste is the default (safer — never auto-edits `config.toml`). If you prefer automation, use the opt-in helper:

```sh
./install.sh --apply            # auto-detects selected_device, writes backup, then runs --check
./install.sh --apply --device "direct:046d:b034:serial:YOURS"  # explicit device when ambiguous
```

`--apply` creates a timestamped backup (`config.toml.bak.<timestamp>`), is idempotent, and ends with `install.sh --check` so you get immediate feedback. Re-run anytime to re-apply after an OpenLogi overwrite — the source of truth stays in `openlogi/per-app-bindings.toml`.

### Verify

```sh
./install.sh --check
```

This validates both the symlink deployment and the `per_app_bindings."com.mitchellh.ghostty"` block. On success:

```
OK: symlink /Users/you/.local/bin/herdr-mouse -> /path/to/repo/bin/herdr-mouse
OK: OpenLogi config /Users/you/.config/openlogi/config.toml contains per_app_bindings."com.mitchellh.ghostty" with required bindings
All checks passed.
```

If anything is wrong it exits nonzero and prints the exact TOML to paste plus a `Fix:` hint. See [Troubleshooting](#troubleshooting) below.

### Restart OpenLogi

After editing `config.toml`, restart OpenLogi (quit from the menu bar or `killall OpenLogi` and relaunch) so it picks up the new overlay. Then focus Ghostty and try the buttons — they should drive herdr immediately.

### Alternative: manual install (no plugin, no symlink deploy)

If you don't use `herdr plugin install`, clone the repo and use `install.sh` only for overlay verification:

```sh
git clone https://github.com/giacolees/herdr-openlogi.git
cd herdr-openlogi
./install.sh --check   # reports symlink status informationally; does not create it
./install.sh --apply   # optional: auto-patch the overlay (backup, idempotent)
```

Symlink deployment has moved to the Bootstrap startup hook (`scripts/bootstrap.sh` via `[[startup]]` in `herdr-plugin.toml`). `install.sh` no longer creates or removes `~/.local/bin/herdr-mouse` — `--check` only reports whether the symlink exists and where it points. Clicks before the first herdr session start (before Bootstrap has run) are a Silent no-op until herdr restores the session and Bootstrap creates the symlink.

---

## Input → Action mapping

While Ghostty is focused, each mouse input fires an OpenLogi `RunShellCommand` → `~/.local/bin/herdr-mouse <action>` → herdr socket-API CLI call.

| Input (device `direct:046d:b034`) | Action | Effect |
| --- | --- | --- |
| Thumb **Back** | `focus-left` | Directional focus left |
| Thumb **Forward** | `focus-right` | Directional focus right |
| Gesture pad **up** | `focus-up` | Directional focus up |
| Gesture pad **down** | `focus-down` | Directional focus down |
| **GestureButton** tap | `zoom-toggle` | Zoom toggle focused pane |
| **DpiToggle** | `next-tab` | Tab cycle — next tab (wraps) |
| Gesture counterpart of DpiToggle | `prev-tab` | Tab cycle — previous tab (wraps) |
| **Thumb wheel rotate up** | `prev-workspace` | Previous workspace (wraps) |
| **Thumb wheel rotate down** | `next-workspace` | Next workspace (wraps) |

* **Directional focus** — moves pane focus one step in a cardinal direction within the current herdr layout (`herdr pane focus --direction <dir>`).
* **Zoom toggle** — expands/collapses the focused pane (`herdr pane zoom`).
* **Tab cycle** — switches to the next/previous tab of the focused workspace, wrapping at the ends. No-ops on a single tab.

When Ghostty is *not* focused, OpenLogi's binding overlay simply isn't active — defaults apply and no script runs. No frontmost-app check lives in the scripts.

All nine actions share a **silent no-op** contract: if the herdr server is unreachable, there's no neighbor pane in that direction, or there's only one tab, the script exits 0 with no stdout, no stderr, and no notification. Mouse actions must never spam the user.

```
# All nine subcommands — every branch honors the silent no-op.
herdr-mouse focus-left
herdr-mouse focus-right
herdr-mouse focus-up
herdr-mouse focus-down
herdr-mouse zoom-toggle
herdr-mouse next-tab
herdr-mouse prev-tab
herdr-mouse next-workspace
herdr-mouse prev-workspace
```

---

## How it works

```
[Logitech mouse] --(OpenLogi per_app_bindings."com.mitchellh.ghostty")-->  /bin/sh -c  -->  ~/.local/bin/herdr-mouse <action>  -->  herdr socket API
                                         |                                            |
                              only when Ghostty is focused               POSIX sh dispatcher, 9 subcommands
                                                                         shared helpers, one artifact
```

* **Gating is OpenLogi-native.** The overlay in `per_app_bindings."com.mitchellh.ghostty"` replaces default button actions only while Ghostty has focus. Scripts never check the frontmost app themselves.
* **One dispatcher, not five scripts.** `bin/herdr-mouse` handles all nine subcommands with shared `herdr`/`jq` resolution and consistent error handling. One deployed artifact, one symlink.
* **Deploy by Bootstrap, verify-and-instruct.** The Bootstrap startup hook (`scripts/bootstrap.sh` via `[[startup]]`) owns the symlink; `install.sh --check` validates the symlink and the TOML and prints the exact snippet to paste when invalid.

### Project layout

```
herdr-plugin.toml             # Plugin manifest (9 actions, [[startup]] → scripts/bootstrap.sh)
bin/herdr-mouse               # POSIX sh dispatcher, 9 subcommands, silent no-op everywhere
scripts/bootstrap.sh          # Bootstrap startup hook — idempotent symlink deploy
install.sh                    # --check verification + --apply overlay patching (no symlink deploy)
openlogi/per-app-bindings.toml # Canonical overlay snippet (device-key-agnostic comment)
```

---

## GUI-PATH caveat

OpenLogi spawns `RunShellCommand` actions via `/bin/sh -c` from its **GUI agent**, which has a minimal `PATH` (typically `/usr/bin:/bin:/usr/sbin:/sbin` — not your login-shell `PATH` with `~/.local/bin` or Homebrew). A naive `herdr` or `jq` on `PATH` would fail to resolve.

`bin/herdr-mouse` therefore **never relies on login-shell `PATH`**. On startup it resolves absolute paths by probing well-known locations before falling back to `command -v`:

* `herdr`: `$HERDR_BIN_PATH` (set by herdr when invoking plugin actions), then `$HOME/.local/bin/herdr`, `/opt/homebrew/bin/herdr`, `/usr/local/bin/herdr`, then `PATH`.
* `jq`: `/opt/homebrew/bin/jq`, `/usr/local/bin/jq`, `/usr/bin/jq`, `/bin/jq`, then `PATH`.

For testing, both are overrideable via environment:

```sh
HERDR_BIN=/nonexistent herdr-mouse focus-right; echo $?  # 0, silent no-op (ISC-2)
JQ_BIN=/nonexistent herdr-mouse next-tab; echo $?        # 0, silent no-op
```

### Debug mode

The dispatcher is silent by design — including when it *skips* an action (no neighbor pane, single tab, herdr unreachable). To see why, set `HERDR_MOUSE_DEBUG=1`:

```sh
HERDR_MOUSE_DEBUG=1 herdr-mouse focus-right
# [herdr-mouse] no-op: cannot focus right (no_neighbor)

HERDR_MOUSE_DEBUG=1 herdr-mouse next-tab
# [herdr-mouse] next tab -> w2A:t5
```

Explanations go to **stderr**; the output contract when the variable is unset is unchanged (silence, exit 0). This also works through OpenLogi — temporarily change a binding to `RunShellCommand = "/bin/sh -c 'HERDR_MOUSE_DEBUG=1 $HOME/.local/bin/herdr-mouse focus-right 2>>/tmp/herdr-mouse.log'"` to capture the reason in a file.

Do not add `PATH`-mutating wrappers around the OpenLogi actions — the dispatcher's absolute resolution already handles the GUI `PATH` correctly.

### Thumb-wheel sensitivity

The thumb wheel fires many events per physical tick — without throttling it can skip workspaces. The Dispatcher debounces `next-workspace` / `prev-workspace` with a 250 ms window (shared between the two directions). Tune it via the environment:

```sh
# Inside the OpenLogi binding (example):
ThumbwheelScrollUp = { RunShellCommand = "HERDR_MOUSE_DEBOUNCE_MS=400 $HOME/.local/bin/herdr-mouse prev-workspace" }
ThumbwheelScrollDown = { RunShellCommand = "HERDR_MOUSE_DEBOUNCE_MS=400 $HOME/.local/bin/herdr-mouse next-workspace" }

# Disable debounce entirely:
HERDR_MOUSE_DEBOUNCE_MS=0 herdr-mouse next-workspace
```

Default `250` ms, `0` disables. With `HERDR_MOUSE_DEBUG=1` a throttled event prints `[herdr-mouse] throttled: next-workspace within 250ms` to stderr.

---

## Uninstall

```sh
# If installed via herdr plugin:
herdr plugin uninstall openlogi.herdr-mouse
rm ~/.local/bin/herdr-mouse  # remove Bootstrap symlink if herdr didn't

# If cloned manually, remove the deployed symlink (leaves the repo intact)
rm ~/.local/bin/herdr-mouse

# Remove the per-app overlay from OpenLogi's config
#    Open ~/.config/openlogi/config.toml and delete the entire block:
#      [devices."<your-device-key>".per_app_bindings."com.mitchellh.ghostty"]
#    ...plus its Back/Forward/GestureButton/DpiToggle lines.
#    Alternatively, delete just the lines you no longer want.

# Restart OpenLogi so the overlay is unloaded.
```

Nothing else is installed — no launch agents, no background services.

---

## Troubleshooting

**Always start here:**

```sh
./install.sh --check
```

This is the single source of truth for deployment health. It checks the symlink *and* the `config.toml` overlay, prints `OK`/`FAIL` per check, and on `FAIL` shows the exact TOML to paste plus a `Fix:` line. Fix what it reports, then re-run `--check` until `All checks passed.` before investigating further.

### Common failures

| Symptom | What `--check` says | Fix |
| --- | --- | --- |
| Buttons do nothing (even inside Ghostty) | `FAIL: per_app_bindings."com.mitchellh.ghostty" block not found` | You pasted the snippet under the wrong header or device key. Re-read [Add the OpenLogi binding overlay](#add-the-openlogi-binding-overlay) — the header must be `[devices."<your-selected_device>".per_app_bindings."com.mitchellh.ghostty"]` under `[devices]`. |
| Buttons do nothing | `FAIL: ... required bindings are missing or incorrect` + lists `Back -> focus-left` etc. | One or more `RunShellCommand` lines don't match exactly. Copy from [`openlogi/per-app-bindings.toml`](openlogi/per-app-bindings.toml) verbatim. The legacy slash form `"$HOME/.local/bin/herdr-mouse/focus-left"` is wrong — use a space: `"$HOME/.local/bin/herdr-mouse focus-left"`. Also check for stray whitespace or missing quotes. |
| Buttons do nothing | `FAIL: symlink missing` or `points to wrong target` | If installed via `herdr plugin install`, restart herdr so the Bootstrap hook creates `~/.local/bin/herdr-mouse → $HERDR_PLUGIN_ROOT/bin/herdr-mouse`. For manual installs, the symlink is still Bootstrap-owned — run herdr once or create it by hand for testing: `ln -sf "$PWD/bin/herdr-mouse" ~/.local/bin/herdr-mouse`. If you moved the repo, reinstall the plugin or retarget the symlink. |
| Buttons do nothing after editing `config.toml` | `--check` passes | Restart OpenLogi. It reads `config.toml` at launch; edits aren't hot-reloaded. |
| `herdr-mouse` works when run manually but not from the mouse | No `--check` failure | Check you are focused on **Ghostty**. The overlay only fires when `com.mitchellh.ghostty` is frontmost — focusing Terminal, iTerm2, etc. uses OpenLogi defaults. Also see the GUI-PATH caveat above. |
| `herdr pane current` doesn't change after a directional action | None — this is expected for some layouts | If there's no neighbor pane in that direction, the action is a silent no-op by design. Try a layout with adjacent panes or check `herdr pane list`. |
| Tab buttons do nothing with one tab | None — expected | Tab cycle no-ops on a single tab. Create a second tab and try again. |
| Thumb wheel skips workspaces / sensitivity too high | — | Debounce is too low. Raise `HERDR_MOUSE_DEBOUNCE_MS` (default 250 ms) in the binding, e.g. `HERDR_MOUSE_DEBOUNCE_MS=400 $HOME/.local/bin/herdr-mouse next-workspace`. See [Thumb-wheel sensitivity](#thumb-wheel-sensitivity). |
| `herdr` or `jq` errors in Console.app | — | The dispatcher suppresses all output on purpose (all calls redirect to `/dev/null` with `\|\| true`). If you see log spam it likely comes from an old pre-canonization script still on `PATH` — ensure `~/.local/bin/herdr-mouse` is a symlink to this repo, not a directory of legacy scripts. `install.sh` removes a legacy directory automatically. |
| OpenLogi overwrote `config.toml` | — | OpenLogi is the owner of this file. Treat your overlay edit as a one-time patch. If it disappears after an OpenLogi update, re-paste the snippet and re-run `--check`. `openlogi/per-app-bindings.toml` in this repo is the backup source of truth. |

### Manual checks

```sh
# Does the dispatcher itself work?
herdr status                              # herdr server reachable?
~/.local/bin/herdr-mouse focus-right; echo $?  # should print 0
herdr pane current                        # did focus move?

# Are the binaries resolvable from a GUI-like PATH?
env -i PATH=/usr/bin:/bin HOME="$HOME" ~/.local/bin/herdr-mouse focus-right; echo $?
# Should still be 0 (absolute resolution). If it fails, check that herdr/jq
# live in one of the probed locations (see GUI-PATH caveat).

# Is the overlay syntactically valid TOML?
grep -A 10 'per_app_bindings\."com\.mitchellh\.ghostty"' ~/.config/openlogi/config.toml
```

If you're still stuck, open an issue with the full output of `./install.sh --check` and `herdr status`.
