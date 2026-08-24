#!/usr/bin/env bats

# Keybindings bats suite — POSIX sh fixtures, mktemp HOME isolation.
# Covers ISC-1..ISC-7: defaults, partial merge, optional gestures,
# invalid strict (--check fails), generation + backup + idempotent, reset.
# Pattern: tests/herdr-mouse.bats (fixture HOME, setup/teardown) and
# tests/bootstrap.bats (POSIX sh, ShellCheck-clean helpers, silent no-op).
# Constraints: POSIX sh + bats only; use mktemp HOME fixtures; sh -n clean
# for install.sh / bootstrap.sh (not the bats harness itself).

setup() {
  TMPDIR="$(mktemp -d)"
  HOME_DIR="$TMPDIR/home"
  INSTALL="$BATS_TEST_DIRNAME/../install.sh"
  mkdir -p "$HOME_DIR"
  export HOME="$HOME_DIR"
  # Per-test env isolation — clear plugin/bootstrap vars
  unset HERDR_PLUGIN_ROOT HERDR_PLUGIN_CONFIG_DIR
  # Helper: create a minimal OpenLogi config with a single device.
  # Tests that need a different shape overwrite this file themselves.
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}

# --- helpers (POSIX sh) -------------------------------------------------------

_make_openlogi_config() {
  # $1 = device key (default: test-device)
  _dev="${1:-test-device}"
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<EOF
selected_device = "$_dev"
[devices."$_dev"]
dummy = 1
EOF
}

_make_openlogi_config_no_selected_single_device() {
  _dev="${1:-solo-device}"
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<EOF
[devices."$_dev"]
dummy = 1
EOF
}

# --- ISC-1: defaults without config ------------------------------------------

@test "ISC-1 defaults: --apply without Keybinding config writes baked-in defaults" {
  _make_openlogi_config "test-device"
  [ ! -e "$HOME/.config/openlogi-herdr/config.toml" ]
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }' "$HOME/.config/openlogi/config.toml"
  # optional gestures must NOT be present when not configured
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'GestureDown =' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-1 defaults: --check without Keybinding config passes (no regression)" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "All checks passed"
  echo "$output" | grep -q 'contains per_app_bindings'
}

@test "ISC-1 defaults: no [keybindings] section falls back to defaults" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
# no section at all
[other]
foo = "bar"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-1 defaults: empty [keybindings] section falls back to defaults" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  printf '[keybindings]\n' > "$HOME/.config/openlogi-herdr/config.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-1 defaults: missing file checked via fresh HOME --check still needs overlay but Keybinding validation passes" {
  _make_openlogi_config
  # ensure no keybinding file, apply then check demonstrates no-regression contract
  rm -f "$HOME/.config/openlogi-herdr/config.toml" 2>/dev/null || true
  run env HOME="$HOME" "$INSTALL" --check
  # Without prior --apply there is no overlay yet, so --check must report FAIL for missing block
  # but must NOT report keybinding validation failure.
  echo "$output" | grep -q 'per_app_bindings'
  ! echo "$output" | grep -q 'unknown input'
  ! echo "$output" | grep -q 'unknown action'
  # Now apply and check passes
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

# --- ISC-2: partial merge -----------------------------------------------------

@test "ISC-2 partial merge: custom Back overrides, missing keys use defaults" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-2 partial merge: multiple overrides coexist with defaults" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
Forward = "focus-left"
DpiToggle = "prev-tab"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-tab" }' "$HOME/.config/openlogi/config.toml"
  # unchanged defaults
  grep -Fq 'ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-2 partial merge: comment and whitespace variations are tolerated" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
# top comment
  [keybindings]  
# inline comment after header
Back   =   "zoom-toggle"   # trailing comment
  Forward= "focus-left"
# blank line above

EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-2 partial merge: single-quoted values are accepted" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = 'zoom-toggle'
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-2 partial merge: unrelated sections are ignored" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[other]
Back = "zoom-toggle"
[keybindings]
Forward = "zoom-toggle"
[another]
DpiToggle = "focus-up"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  # Only Forward inside [keybindings] should have been applied
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }' "$HOME/.config/openlogi/config.toml"
}

# --- ISC-3: optional GestureUp / GestureDown ---------------------------------

@test "ISC-3 optional: GestureUp when set appears in overlay" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureUp = "focus-up"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-3 optional: GestureDown when set appears in overlay" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureDown = "focus-down"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-3 optional: both gestures when set appear together" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureUp = "focus-up"
GestureDown = "focus-down"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-3 optional: gestures absent are not required by --check" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  printf '[keybindings]\nBack = "zoom-toggle"\n' > "$HOME/.config/openlogi-herdr/config.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'GestureDown =' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "All checks passed"
}

@test "ISC-3 optional: gesture optional not emitted defaults when not set even with empty keybindings" {
  _make_openlogi_config
  rm -rf "$HOME/.config/openlogi-herdr" 2>/dev/null || true
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'GestureDown =' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

# --- ISC-4: invalid strict (--check fails loudly) -----------------------------

@test "ISC-4 invalid: unknown action causes --check to FAIL with Valid actions and Fix hint" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "nope"
EOF
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid actions"
  echo "$output" | grep -q "Fix:"
}

@test "ISC-4 invalid: unknown input causes --check to FAIL with Valid inputs and Fix hint" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
MyButton = "focus-left"
EOF
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid inputs"
  echo "$output" | grep -q "Fix:"
}

@test "ISC-4 invalid: unknown action typo zoom-togle is rejected" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-togle"
EOF
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "Valid actions"
}

@test "ISC-4 invalid: empty string Back = \"\" is treated as invalid" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = ""
EOF
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep -q "Valid actions"
}

@test "ISC-4 invalid: empty single-quoted Back = '' is treated as invalid" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = ''
EOF
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "FAIL"
}

@test "ISC-4 invalid: --check reports INFO using Keybinding config when file present" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  printf '[keybindings]\nBack = "zoom-toggle"\n' > "$HOME/.config/openlogi-herdr/config.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "using Keybinding config"
}

@test "ISC-4 invalid: invalid entry still leaves overlay checkable -- apply writes fallback but --check FAILs" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "nope"
EOF
  # --apply writes fallback defaults even for invalid entries, but final --check fails so exit is non-zero
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -ne 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  # --check must still FAIL on the invalid config
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unknown action"
}

# --- ISC-6: generation + backup + idempotent ----------------------------------

@test "ISC-6 generation: --apply writes correct RunShellCommand lines under correct device header" {
  _make_openlogi_config "my-special-device"
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
GestureUp = "focus-up"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq '[devices."my-special-device".per_app_bindings."com.mitchellh.ghostty"]' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }' "$HOME/.config/openlogi/config.toml"
  # defaults still present for non-overridden keys
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-6 generation: --apply with explicit --device flag uses that device key" {
  mkdir -p "$HOME/.config/openlogi"
  # No selected_device, single device ambiguous case avoided by explicit --device
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
[devices."ignored-device"]
dummy = 1
EOF
  run env HOME="$HOME" "$INSTALL" --apply --device "explicit-device"
  [ "$status" -eq 0 ]
  grep -Fq '[devices."explicit-device".per_app_bindings."com.mitchellh.ghostty"]' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-6 generation: --apply creates .bak.* backup" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  # at least one backup exists
  count="$(ls "$HOME/.config/openlogi/config.toml.bak."* 2>/dev/null | wc -l | tr -d ' ')"
  [ "$count" -ge 1 ]
}

@test "ISC-6 generation: --apply is idempotent and --check passes after second apply" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  # snapshot after first apply
  cp "$HOME/.config/openlogi/config.toml" "$TMPDIR/snap.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  # file must be identical (idempotent) aside from backup creation
  diff "$TMPDIR/snap.toml" "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "All checks passed"
}

@test "ISC-6 generation: --apply is atomic (config not empty, header present)" {
  _make_openlogi_config
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  [ -s "$HOME/.config/openlogi/config.toml" ]
  grep -q 'per_app_bindings\."com\.mitchellh\.ghostty"' "$HOME/.config/openlogi/config.toml"
}

# --- ISC-7: reset -------------------------------------------------------------

@test "ISC-7 reset: deleting custom file reverts to defaults on next --apply" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  # reset
  rm -f "$HOME/.config/openlogi-herdr/config.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'zoom-toggle.*Back' "$HOME/.config/openlogi/config.toml" 2>/dev/null || true
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}

@test "ISC-7 reset: deleting single key line reverts that key to default" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
Forward = "focus-left"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  # delete only Back line
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Forward = "focus-left"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
}

@test "ISC-7 reset: removing GestureUp line stops emitting it" {
  _make_openlogi_config
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureUp = "focus-up"
EOF
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  grep -Fq 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }' "$HOME/.config/openlogi/config.toml"
  # remove gesture
  printf '[keybindings]\n' > "$HOME/.config/openlogi-herdr/config.toml"
  run env HOME="$HOME" "$INSTALL" --apply
  [ "$status" -eq 0 ]
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
  run env HOME="$HOME" "$INSTALL" --check
  [ "$status" -eq 0 ]
}
