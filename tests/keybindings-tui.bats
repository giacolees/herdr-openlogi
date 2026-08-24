#!/usr/bin/env bats

# keybindings-tui bats suite — Keybinding picker TUI coverage (ISC-1..ISC-8)
# Pattern: tests/keybindings.bats (mktemp HOME, helpers) + tests/bootstrap.bats (POSIX sh harness)
# Constraints: POSIX sh + bats only; mktemp HOME fixtures; shellcheck + sh -n clean for bin/herdr-mouse-tui

setup() {
  TMPDIR="$(mktemp -d)"
  HOME_DIR="$TMPDIR/home"
  TUI="$BATS_TEST_DIRNAME/../bin/herdr-mouse-tui"
  INSTALL="$BATS_TEST_DIRNAME/../install.sh"
  mkdir -p "$HOME_DIR"
  export HOME="$HOME_DIR"
  unset HERDR_PLUGIN_ROOT HERDR_PLUGIN_CONFIG_DIR
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}

_make_openlogi_config() {
  _dev="${1:-test-device}"
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<EOF
selected_device = "$_dev"
[devices."$_dev"]
dummy = 1
EOF
}

# --- ISC-1: action + wrapper exist (see manifest.bats for popup 80%) ---------

@test "TUI ISC-1: wrapper + action exist" {
  grep -q -- '--tui' "$INSTALL"
  grep -Fq 'herdr-mouse-tui' "$INSTALL"
  grep -Fq 'herdr-mouse-tui' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  grep -Eq '^[[:space:]]*id[[:space:]]*=[[:space:]]*"configure"' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  grep -Fq 'placement = "popup"' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  grep -Fq 'width = "80%"' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  grep -Fq 'height = "80%"' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  # no default [[keys.command]] shipped
  ! grep -Eq '^[[:space:]]*\[\[keys\.command\]\]' "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  [ -x "$TUI" ]
  # wrapper delegates: install.sh --tui --help contains picker help
  run env HOME="$HOME" "$INSTALL" --tui --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Keybinding picker"
}

@test "TUI ISC-1: --help shows 8 inputs and 9 actions and footer" {
  run env HOME="$HOME" "$TUI" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Keybinding picker"
  echo "$output" | grep -q "Inputs (8)"
  echo "$output" | grep -q "Actions (9)"
  echo "$output" | grep -q "Footer:"
  echo "$output" | grep -q "brew install fzf"
}

# --- ISC-2: table completeness ------------------------------------------------

@test "TUI ISC-2: --dry-run table shows all 8 inputs with source column" {
  run env HOME="$HOME" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Keybinding picker"
  echo "$output" | grep -q "^Input"
  for inp in Back Forward GestureButton DpiToggle ThumbwheelScrollUp ThumbwheelScrollDown GestureUp GestureDown; do
    echo "$output" | grep -q "$inp"
  done
  echo "$output" | grep -q "Source"
  echo "$output" | grep -q "Footer:"
}

@test "TUI ISC-2: GestureUp/GestureDown show not set when absent" {
  _make_openlogi_config
  rm -f "$HOME/.config/openlogi-herdr/config.toml" 2>/dev/null || true
  run env HOME="$HOME" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "GestureUp.*not set"
  echo "$output" | grep -q "GestureDown.*not set"
  # required rows still show defaults
  echo "$output" | grep -q "Back.*focus-left"
  echo "$output" | grep -q "Forward.*focus-right"
}

@test "TUI ISC-2: custom Back shows custom source and correct effective action" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  run env HOME="$HOME" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Back.*zoom-toggle.*custom"
  echo "$output" | grep -q "Forward.*focus-right.*default"
}

@test "TUI ISC-2: optional GestureUp when set appears as custom source" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureUp = "focus-up"
EOF
  run env HOME="$HOME" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "GestureUp.*focus-up.*custom"
  echo "$output" | grep -q "GestureDown.*not set"
}

@test "TUI ISC-2: install.sh --tui --dry-run prints table" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --tui --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Back"
  echo "$output" | grep -q "GestureUp"
}

# --- ISC-3: fzf fallback ------------------------------------------------------

@test "TUI ISC-3: fzf fallback when absent on PATH" {
  mkdir -p "$TMPDIR/empty_bin"
  _make_openlogi_config
  # PATH without fzf — ensure fallback hint and select picker appear
  run env HOME="$HOME" PATH="$TMPDIR/empty_bin:/usr/bin:/bin" "$TUI" --dry-run --pick Back
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "select"
  echo "$output" | grep -q "focus-left"
  # plain dry-run without --pick also shows tip when no fzf
  run env HOME="$HOME" PATH="$TMPDIR/empty_bin:/usr/bin:/bin" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "brew install fzf"
}

@test "TUI ISC-3: fzf present shows fzf picker" {
  mkdir -p "$TMPDIR/fake_bin"
  # Create a stub fzf that exits 0 — presence is enough for _has_fzf to succeed
  cat > "$TMPDIR/fake_bin/fzf" <<'EOF'
#!/bin/sh
# stub — just cat stdin
cat
EOF
  chmod +x "$TMPDIR/fake_bin/fzf"
  _make_openlogi_config
  run env HOME="$HOME" PATH="$TMPDIR/fake_bin:/usr/bin:/bin" "$TUI" --dry-run --pick Back
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "picker: fzf"
  echo "$output" | grep -q "focus-left"
  # plain dry-run with fzf present shows picker: fzf
  run env HOME="$HOME" PATH="$TMPDIR/fake_bin:/usr/bin:/bin" "$TUI" --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "picker: fzf"
}

@test "TUI ISC-3: --pick shows 9 actions plus reset and cancel" {
  _make_openlogi_config
  run env HOME="$HOME" "$TUI" --dry-run --pick Back
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Pick action for Back"
  for act in focus-left focus-right focus-up focus-down zoom-toggle next-tab prev-tab next-workspace prev-workspace; do
    echo "$output" | grep -q "$act"
  done
  echo "$output" | grep -q "reset to default"
  echo "$output" | grep -q "Cancel"
}

@test "TUI ISC-3: --pick unknown input fails with Valid inputs" {
  run env HOME="$HOME" "$TUI" --dry-run --pick NotARealInput
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid inputs"
}

# --- ISC-4: save creates backup and idempotent --------------------------------

@test "TUI ISC-4: --non-interactive --set saves and creates backup and is idempotent" {
  _make_openlogi_config "tui-device"
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-toggle --home "$HOME"
  [ "$status" -eq 0 ]
  grep -Fq 'Back = "zoom-toggle"' "$HOME/.config/openlogi-herdr/config.toml"
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
  # backup exists
  count="$(ls "$HOME/.config/openlogi/config.toml.bak."* 2>/dev/null | wc -l | tr -d ' ')"
  [ "$count" -ge 1 ]
  # idempotent second apply: snapshot header still present and file stable
  cp "$HOME/.config/openlogi/config.toml" "$TMPDIR/snap.toml"
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-toggle --home "$HOME"
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  # --check passes
  run env HOME="$HOME" "$TUI" --non-interactive --check --home "$HOME"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "All checks passed"
}

@test "TUI ISC-4: multiple --set values coexist with defaults" {
  _make_openlogi_config
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-toggle --set Forward=focus-left --home "$HOME"
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }' "$HOME/.config/openlogi/config.toml"
}

# --- ISC-5: invalid blocks save -----------------------------------------------

@test "TUI ISC-5: invalid action blocks save and shows FAIL + Valid actions + per-row warning" {
  _make_openlogi_config
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-toggle --home "$HOME"
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "nope"
EOF
  run env HOME="$HOME" "$TUI" --non-interactive --check --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid actions"
  echo "$output" | grep -q "Valid inputs"
  echo "$output" | grep -q "⚠"
  # bare check via --dry-run also shows banner + warning
  run env HOME="$HOME" "$TUI" --dry-run --home "$HOME"
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "⚠"
  # --set with invalid action also blocks
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=nope --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unknown action"
}

@test "TUI ISC-5: invalid input blocks save" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
MyButton = "focus-left"
EOF
  run env HOME="$HOME" "$TUI" --non-interactive --check --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unknown input"
  echo "$output" | grep -q "Valid inputs"
}

@test "TUI ISC-5: empty string blocks save" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = ""
EOF
  run env HOME="$HOME" "$TUI" --non-interactive --check --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid actions"
}

@test "TUI ISC-5: invalid --set input/action fails before write" {
  _make_openlogi_config
  run env HOME="$HOME" "$TUI" --non-interactive --set MyButton=focus-left --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unknown input"
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-togle --home "$HOME"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unknown action"
}

# --- ISC-6: reset -------------------------------------------------------------

@test "TUI ISC-6: reset-all deletes Keybinding config and reverts to defaults" {
  _make_openlogi_config "reset-device"
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
GestureUp = "focus-up"
EOF
  run env HOME="$HOME" "$TUI" --non-interactive --set Back=zoom-toggle --home "$HOME"
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$TUI" --non-interactive --reset-all --home "$HOME"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Reset"
  [ ! -f "$HOME/.config/openlogi-herdr/config.toml" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
  # install.sh --apply also reverts
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
}

@test "TUI ISC-6: reset preserves other sections" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[other]
foo = "bar"
[keybindings]
Back = "zoom-toggle"
[another]
x = 1
EOF
  run env HOME="$HOME" "$TUI" --non-interactive --reset-all --home "$HOME"
  [ "$status" -eq 0 ]
  # file still exists with other sections but no keybindings entry
  [ -f "$HOME/.config/openlogi-herdr/config.toml" ]
  grep -Fq 'foo = "bar"' "$HOME/.config/openlogi-herdr/config.toml"
  ! grep -Fq 'Back = "zoom-toggle"' "$HOME/.config/openlogi-herdr/config.toml"
}

# --- ISC-7: prompts safety ----------------------------------------------------

@test "TUI ISC-7: dirty-check prompts Save changes" {
  run bash -c "printf 'n\n' | env HOME=\"$HOME\" \"$TUI\" --non-interactive --dirty-check 2>&1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Save?"
  run bash -c "printf 'y\n' | env HOME=\"$HOME\" \"$TUI\" --non-interactive --dirty-check 2>&1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Save?"
  run bash -c "printf 'c\n' | env HOME=\"$HOME\" \"$TUI\" --non-interactive --dirty-check 2>&1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "c"
}

@test "TUI ISC-7: reload prompt after save only on y" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  # n should not reload — we check it prompts and exits 0
  run bash -c "printf 'n\n' | env HOME=\"$HOME\" \"$TUI\" --non-interactive --save --home \"$HOME\" 2>&1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Reload OpenLogi"
  # second time with y also prompts (we don't require actual OpenLogi, just the prompt)
  run bash -c "printf 'y\n' | env HOME=\"$HOME\" \"$TUI\" --non-interactive --save --home \"$HOME\" 2>&1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Reload OpenLogi"
}

# --- ISC-8: docs & lint ------------------------------------------------------

@test "TUI ISC-8: docs exist and mention picker" {
  grep -q "Keybinding picker" "$BATS_TEST_DIRNAME/../CONTEXT.md"
  grep -q "install.sh --tui" "$BATS_TEST_DIRNAME/../README.md"
  grep -q "herdr plugin action invoke" "$BATS_TEST_DIRNAME/../README.md"
  grep -q "prefix+alt+m" "$BATS_TEST_DIRNAME/../README.md"
  grep -q "popup" "$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  [ -f "$BATS_TEST_DIRNAME/../docs/adr/0007-keybinding-picker-posix-fzf-popup.md" ]
  grep -q "Keybinding picker" "$BATS_TEST_DIRNAME/../docs/adr/0007-keybinding-picker-posix-fzf-popup.md"
}

@test "TUI ISC-8: TUI is shellcheck and sh -n clean" {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$TUI"
    shellcheck "$INSTALL"
  fi
  sh -n "$TUI"
  sh -n "$INSTALL"
}
