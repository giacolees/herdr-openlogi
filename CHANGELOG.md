# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-08-24

### Fixed

- CI smoke now matches Bootstrap-owned symlink contract (bare `install.sh` shows usage, `--check` reports `INFO: symlink`) and covers `scripts/bootstrap.sh`.

### Added

- Release workflow (`.github/workflows/release.yml`) on `v*` tags: validates, extracts changelog, creates GitHub Release.
- Bootstrap opt-in overlay auto-patch via `$(herdr plugin config-dir openlogi.herdr-mouse)/auto-apply` flag (lean install).

### Changed

- Install docs: lean automatic path is now Recommended with overwrite warning; manual remains as alternative.

## [0.2.0] - 2026-08-24

### Added

- herdr plugin manifest (`herdr-plugin.toml`) making the repo installable via
  `herdr plugin install giacolees/herdr-openlogi` and listable on
  <https://herdr.dev/plugins/> (requires `herdr >= 0.7.0`, `platforms = ["macos", "linux"]`).
  Declares nine `[[actions]]` — one per Dispatcher subcommand
  (`focus-left`, `focus-right`, `focus-up`, `focus-down`, `zoom-toggle`,
  `next-tab`, `prev-tab`, `next-workspace`, `prev-workspace`) — each as an
  argv array starting with `bin/herdr-mouse`.
- Bootstrap startup hook (`scripts/bootstrap.sh` via `[[startup]]`) that
  idempotently symlinks `~/.local/bin/herdr-mouse → $HERDR_PLUGIN_ROOT/bin/herdr-mouse`
  once after session restore; re-run retargets a stale symlink, missing
  `HERDR_PLUGIN_ROOT` or target is a silent no-op.
- Marketplace discoverability: owner adds the `herdr-plugin` GitHub topic to
  `giacolees/herdr-openlogi` at release (index refresh ≤ 30 min).

### Changed

- Dispatcher (`bin/herdr-mouse`) now prefers `HERDR_BIN_PATH` when set (herdr
  plugin runtime env) before the existing absolute-path probe chain; unset
  behaviour is byte-identical to the direct OpenLogi dispatch path.
- `install.sh` no longer creates or removes the `~/.local/bin/herdr-mouse`
  symlink — ownership moved to the Bootstrap startup hook. `--check` now
  reports symlink status informationally only; `--apply` still patches the
  OpenLogi overlay as before.
- Docs: reconciled prose drift — seven → nine Dispatcher subcommands
  (enumerated from the `case "$cmd"` block in `bin/herdr-mouse`).

## [0.1.1] - 2026-08-23

### Fixed

- Thumb-wheel Workspace cycle no longer skips workspaces on fast scrolls.
  Added 250 ms debounce (shared between `next-workspace` / `prev-workspace`)
  via timestamp file (`/tmp/herdr-mouse.throttle.workspace`). Tune with
  `HERDR_MOUSE_DEBOUNCE_MS` (default `250`, `0` disables) or override dir
  with `HERDR_MOUSE_THROTTLE_DIR` for testing. Throttled events are silent
  unless `HERDR_MOUSE_DEBUG=1`.

## [0.1.0] - 2026-08-23

### Added

- Initial release of the 7-action Dispatcher (`bin/herdr-mouse`, POSIX `sh`).
  Gated by the OpenLogi Binding overlay (`per_app_bindings."com.mitchellh.ghostty"`):
  `focus-left` / `focus-right` (Directional focus via `herdr pane focus`),
  `focus-up` / `focus-down` (optional vertical Directional focus),
  `zoom-toggle` (Zoom toggle via `herdr pane zoom`),
  `next-tab` / `prev-tab` (Tab cycle with wrap-around),
  `next-workspace` / `prev-workspace` (Workspace cycle with wrap-around).
  Every subcommand honours the Silent no-op contract — exit 0 with no output
  when herdr is unreachable, `jq` is missing, or the move is impossible
  (no neighbour pane, single tab/workspace, unknown subcommand).
- Symlink deploy at `~/.local/bin/herdr-mouse` via `install.sh`
  (idempotent, replaces stale target / legacy directory).
- Verifiable setup via `install.sh --check` (symlink + overlay validation
  with `Fix:` hints).
- Canonical Binding overlay snippet at `openlogi/per-app-bindings.toml`
  (Back, Forward, GestureButton, DpiToggle, ThumbwheelScrollUp/Down plus
  optional GestureUp/GestureDown).
- GUI-PATH-safe absolute resolution for `herdr` and `jq` with
  `HERDR_BIN`/`JQ_BIN` overrides for testing; opt-in debug via
  `HERDR_MOUSE_DEBUG=1` and `/tmp/herdr-mouse.debug` trace.
