#!/usr/bin/env bats

# herdr-mouse dispatcher bats suite — POSIX sh fixtures, mocked HERDR_BIN/JQ_BIN
# Covers ISC-9: 7+2 happy subcommands + silent no-op cases.

setup() {
  export TMPDIR
  TMPDIR="$(mktemp -d)"
  export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export MOCK_LOG="$TMPDIR/herdr.log"
  export HERDR_BIN="$FIXTURES/mock-herdr"
  export JQ_BIN="$FIXTURES/mock-jq"
  chmod +x "$HERDR_BIN" "$JQ_BIN" 2>/dev/null || true
  # ensure dispatcher trace flag does not interfere
  rm -f /tmp/herdr-mouse.debug /tmp/herdr-mouse.debug.log 2>/dev/null || true
  # clear per-test mock controls
  unset MOCK_HERDR_FAIL MOCK_JQ_FAIL MOCK_FOCUS_CHANGED MOCK_TAB_MODE MOCK_WS_MODE
  unset HERDR_MOUSE_DEBUG
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
  rm -f /tmp/herdr-mouse.debug /tmp/herdr-mouse.debug.log 2>/dev/null || true
}

# --- happy: directional focus ---

@test "focus-left happy invokes herdr pane focus --direction left" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "pane focus --direction left" "$MOCK_LOG"
}

@test "focus-right happy" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-right
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "pane focus --direction right" "$MOCK_LOG"
}

@test "focus-up happy" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-up
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "pane focus --direction up" "$MOCK_LOG"
}

@test "focus-down happy" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-down
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "pane focus --direction down" "$MOCK_LOG"
}

# --- happy: zoom toggle ---

@test "zoom-toggle happy invokes herdr pane zoom" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" zoom-toggle
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "pane zoom" "$MOCK_LOG"
}

# --- happy: tab cycle ---

@test "next-tab happy cycles to next tab" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "workspace list" "$MOCK_LOG"
  grep -q "tab list" "$MOCK_LOG"
  grep -q "tab focus tab-2" "$MOCK_LOG"
}

@test "prev-tab happy cycles to previous tab" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" prev-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "tab focus tab-2" "$MOCK_LOG"
}

# --- happy: workspace cycle ---

@test "next-workspace happy cycles to next workspace" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "workspace list" "$MOCK_LOG"
  grep -q "workspace focus ws-2" "$MOCK_LOG"
}

@test "prev-workspace happy cycles to previous workspace" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" prev-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -q "workspace focus ws-2" "$MOCK_LOG"
}

# --- silent no-op: herdr unreachable ---

@test "focus-left silent no-op when herdr unreachable" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_HERDR_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "zoom-toggle silent no-op when herdr unreachable" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_HERDR_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" zoom-toggle
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "next-tab silent no-op when herdr unreachable" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_HERDR_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "next-workspace silent no-op when herdr unreachable" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_HERDR_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- silent no-op: jq missing ---

@test "focus-left silent no-op when jq missing" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_JQ_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "next-tab silent no-op when jq missing" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_JQ_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "zoom-toggle silent no-op when jq missing" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_JQ_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" zoom-toggle
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "next-workspace silent no-op when jq missing" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_JQ_FAIL=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Also cover jq binary path does not exist (env override to nonexistent)
@test "jq missing via nonexistent JQ_BIN is silent no-op" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="/nonexistent/jq" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- silent no-op: single tab / single workspace ---

@test "next-tab silent no-op with single tab" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_TAB_MODE=single "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # should not have attempted tab focus
  ! grep -q "tab focus" "$MOCK_LOG" 2>/dev/null || false
}

@test "prev-tab silent no-op with single tab" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_TAB_MODE=single "$BATS_TEST_DIRNAME/../bin/herdr-mouse" prev-tab
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q "tab focus" "$MOCK_LOG" 2>/dev/null || false
}

@test "next-workspace silent no-op with single workspace" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_WS_MODE=single "$BATS_TEST_DIRNAME/../bin/herdr-mouse" next-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q "workspace focus" "$MOCK_LOG" 2>/dev/null || false
}

@test "prev-workspace silent no-op with single workspace" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_WS_MODE=single "$BATS_TEST_DIRNAME/../bin/herdr-mouse" prev-workspace
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q "workspace focus" "$MOCK_LOG" 2>/dev/null || false
}

# --- silent no-op: no neighbor pane ---

@test "focus-left silent no-op when no neighbor pane" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_FOCUS_CHANGED=false "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "focus-right silent no-op when no neighbor pane with debug" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_FOCUS_CHANGED=false HERDR_MOUSE_DEBUG=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-right
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "no-op"
}

# --- silent no-op: unknown subcommand ---

@test "unknown subcommand is silent no-op" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse" unknown-cmd
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing subcommand (no args) is silent no-op" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" "$BATS_TEST_DIRNAME/../bin/herdr-mouse"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unknown subcommand with HERDR_MOUSE_DEBUG prints debug line" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" HERDR_MOUSE_DEBUG=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" unknown-cmd
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "unknown subcommand"
}

@test "herdr unreachable with HERDR_MOUSE_DEBUG prints debug" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" MOCK_HERDR_FAIL=1 HERDR_MOUSE_DEBUG=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "herdr pane focus"
}

# --- debug happy still exits 0 and prints ---

@test "focus-left happy with HERDR_MOUSE_DEBUG prints moved" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" HERDR_MOUSE_DEBUG=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" focus-left
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "focus moved"
}

@test "zoom-toggle happy with HERDR_MOUSE_DEBUG prints zoomed" {
  run env HERDR_BIN="$HERDR_BIN" JQ_BIN="$JQ_BIN" MOCK_LOG="$MOCK_LOG" HERDR_MOUSE_DEBUG=1 "$BATS_TEST_DIRNAME/../bin/herdr-mouse" zoom-toggle
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "zoomed"
}
