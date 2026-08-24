# Keybinding config owns mapping; Binding overlay is derived

The user-owned `~/.config/openlogi-herdr/config.toml` `[keybindings]` table is the source of truth for mouse-input → Dispatcher-action mapping; `~/.config/openlogi/config.toml`'s `per_app_bindings."com.mitchellh.ghostty"` block is always (re)generated from it merged with baked-in defaults in `openlogi/per-app-bindings.toml`.

We chose a standalone `openlogi-herdr` config dir over `$(herdr plugin config-dir …)` so manual installs and plugin installs share one stable path, and we chose merge-with-defaults over exact-replace so a one-line override doesn't require copying all six bindings.

Considered Options: store in plugin config-dir (volatile, plugin-mapped, not discoverable for manual installs); treat the OpenLogi file as directly hand-edited (loses single source of truth and makes Bootstrap reconciliation racy); require full replacement (friction for single-key tweaks).

Consequences: `install.sh --apply` and `scripts/bootstrap.sh` are the only writers; direct hand-edits to the OpenLogi block are overwritten on next apply/restart (documented).
