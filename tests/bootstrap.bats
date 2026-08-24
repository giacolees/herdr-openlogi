#!/usr/bin/env bats

# Bootstrap bats suite — verifies ISC-4: the startup hook idempotently
# symlinks $HOME/.local/bin/herdr-mouse -> $HERDR_PLUGIN_ROOT/bin/herdr-mouse
# POSIX sh, ShellCheck-clean, silent no-op contract.

setup() {
  TMPDIR="$(mktemp -d)"
  PLUGIN_ROOT="$TMPDIR/plugin"
  HOME_DIR="$TMPDIR/home"
  BOOTSTRAP="$BATS_TEST_DIRNAME/../scripts/bootstrap.sh"
  mkdir -p "$PLUGIN_ROOT/bin"
  mkdir -p "$HOME_DIR"
  # fake dispatcher target
  touch "$PLUGIN_ROOT/bin/herdr-mouse"
  chmod +x "$PLUGIN_ROOT/bin/herdr-mouse"
  export HOME="$HOME_DIR"
  export HERDR_PLUGIN_ROOT="$PLUGIN_ROOT"
  # ensure no leftover symlink
  rm -f "$HOME/.local/bin/herdr-mouse" 2>/dev/null || true
  rm -rf "$HOME/.local" 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}

@test "bootstrap script exists and is executable" {
  [ -f "$BOOTSTRAP" ]
  [ -x "$BOOTSTRAP" ]
}

@test "bootstrap is POSIX sh and shellcheck-clean" {
  sh -n "$BOOTSTRAP"
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$BOOTSTRAP"
  fi
}

@test "bootstrap creates missing symlink" {
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -L "$HOME/.local/bin/herdr-mouse" ]
  target="$HERDR_PLUGIN_ROOT/bin/herdr-mouse"
  [ "$(readlink "$HOME/.local/bin/herdr-mouse")" = "$target" ]
}

@test "bootstrap creates parent dir if missing" {
  [ ! -e "$HOME/.local" ]
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -d "$HOME/.local/bin" ]
  [ -L "$HOME/.local/bin/herdr-mouse" ]
}

@test "bootstrap is idempotent when symlink already correct" {
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  first_link="$(readlink "$HOME/.local/bin/herdr-mouse")"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  second_link="$(readlink "$HOME/.local/bin/herdr-mouse")"
  [ "$first_link" = "$second_link" ]
  [ "$second_link" = "$HERDR_PLUGIN_ROOT/bin/herdr-mouse" ]
}

@test "bootstrap retargets symlink pointing elsewhere" {
  mkdir -p "$HOME/.local/bin"
  ln -sf "/tmp/wrong-target" "$HOME/.local/bin/herdr-mouse"
  [ "$(readlink "$HOME/.local/bin/herdr-mouse")" = "/tmp/wrong-target" ]
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(readlink "$HOME/.local/bin/herdr-mouse")" = "$HERDR_PLUGIN_ROOT/bin/herdr-mouse" ]
}

@test "bootstrap replaces regular file at link path" {
  mkdir -p "$HOME/.local/bin"
  printf 'old' > "$HOME/.local/bin/herdr-mouse"
  [ -f "$HOME/.local/bin/herdr-mouse" ]
  [ ! -L "$HOME/.local/bin/herdr-mouse" ]
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -L "$HOME/.local/bin/herdr-mouse" ]
  [ "$(readlink "$HOME/.local/bin/herdr-mouse")" = "$HERDR_PLUGIN_ROOT/bin/herdr-mouse" ]
}

@test "bootstrap exits 0 silently when HERDR_PLUGIN_ROOT unset" {
  run env -u HERDR_PLUGIN_ROOT HOME="$HOME" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$HOME/.local/bin/herdr-mouse" ]
}

@test "bootstrap exits 0 silently when HERDR_PLUGIN_ROOT empty" {
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$HOME/.local/bin/herdr-mouse" ]
}

@test "bootstrap exits 0 silently when target missing" {
  rm -f "$PLUGIN_ROOT/bin/herdr-mouse"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$HOME/.local/bin/herdr-mouse" ]
  [ ! -L "$HOME/.local/bin/herdr-mouse" ]
}

@test "bootstrap produces no stdout on success" {
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # stdout should be empty; also check file has no stray output on second run
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bootstrap produces no stdout when no-op (env unset)" {
  run env -u HERDR_PLUGIN_ROOT HOME="$HOME" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bootstrap produces no stdout when no-op (target missing)" {
  rm -f "$PLUGIN_ROOT/bin/herdr-mouse"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- overlay auto-patch (ISC-1..ISC-7 via Bootstrap, ISC-5 lenient) ----------

@test "bootstrap with auto-apply and no custom file writes defaults (ISC-1)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq '[devices."test-device".per_app_bindings."com.mitchellh.ghostty"]' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
  ! grep -Fq 'GestureUp =' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap with auto-apply and partial custom merge (ISC-2)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap with auto-apply and optional GestureUp (ISC-3)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
GestureUp = "focus-up"
GestureDown = "focus-down"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap ignores invalid keybinding and uses defaults for bad entries (ISC-5 unknown action)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "nope"
Forward = "focus-right"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
  grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap ignores invalid keybinding unknown input (ISC-5)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
MyButton = "focus-left"
Back = "zoom-toggle"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap ignores empty string action and falls back to default (ISC-5)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = ""
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap with auto-apply still succeeds silently when keybinding file has only invalid entries" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "nope"
MyButton = "focus-left"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap is idempotent for overlay (second run no change, silent)" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  mkdir -p "$HOME/.config/openlogi-herdr"
  cat > "$HOME/.config/openlogi-herdr/config.toml" <<'EOF'
[keybindings]
Back = "zoom-toggle"
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  cp "$HOME/.config/openlogi/config.toml" "$TMPDIR/snap.toml"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  diff "$TMPDIR/snap.toml" "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap with auto-apply creates backup on overlay patch" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  touch "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  count="$(ls "$HOME/.config/openlogi/config.toml.bak."* 2>/dev/null | wc -l | tr -d ' ')"
  [ "$count" -ge 1 ]
}

@test "bootstrap without auto-apply does not patch overlay" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
selected_device = "test-device"
[devices."test-device"]
dummy = 1
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  # no auto-apply file
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q 'per_app_bindings' "$HOME/.config/openlogi/config.toml"
}

@test "bootstrap with auto-apply and explicit device key from flag file" {
  mkdir -p "$HOME/.config/openlogi"
  cat > "$HOME/.config/openlogi/config.toml" <<'EOF'
[devices."ignored"]
dummy = 1
EOF
  cfg_dir="$TMPDIR/cfg"
  mkdir -p "$cfg_dir"
  printf 'explicit-device\n' > "$cfg_dir/auto-apply"
  run env HOME="$HOME" HERDR_PLUGIN_ROOT="$HERDR_PLUGIN_ROOT" HERDR_PLUGIN_CONFIG_DIR="$cfg_dir" "$BOOTSTRAP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq '[devices."explicit-device".per_app_bindings."com.mitchellh.ghostty"]' "$HOME/.config/openlogi/config.toml"
}
