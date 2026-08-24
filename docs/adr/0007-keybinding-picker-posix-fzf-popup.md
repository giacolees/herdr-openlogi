# Keybinding picker: POSIX sh + fzf with herdr popup action

The `Keybinding picker` — see `CONTEXT.md` — is a POSIX `sh` script (`bin/herdr-mouse-tui`) using `fzf` for selection with a `select`-loop fallback when `fzf` is absent, exposed as a herdr `popup` plugin action (`[[actions]] id="configure"`) and via `install.sh --tui` for manual installs. We chose this over a compiled Go/Bubbletea or `gum`/`dialog` dependency to preserve the repo's POSIX `sh` + `jq` only constraint and avoid a build step, while the `popup` surface makes the picker discoverable from herdr's action list and bindable via `[[keys.command]]` without claiming a default key.

Considered Options: Go/Bubbletea compiled TUI (richer table, adds toolchain and release artifact); `gum`/`dialog`/`choose` (extra runtime dep, not preinstalled); pure `sh` without `fzf` (falls back to numbered menu only, weaker picker); plugin `pane` or `shell` action instead of `popup` (disturbs layout or has no UI).

Consequences: `shellcheck`/`sh -n` remain the lint gate; tests use `mktemp HOME` fixtures with `PATH` without `fzf` to cover the fallback; no default `[[keys.command]]` is shipped — README documents a `prefix+alt+m` recipe.
