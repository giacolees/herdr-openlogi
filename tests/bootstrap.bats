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
