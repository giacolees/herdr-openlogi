#!/usr/bin/env bats

# manifest sanity — validates herdr-plugin.toml required keys and that every
# action's argv[0] resolves to an executable inside the repo. Uses only
# POSIX tools (grep, sed, awk); no external deps.

setup() {
  MANIFEST="$BATS_TEST_DIRNAME/../herdr-plugin.toml"
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
}

@test "manifest exists at repo root" {
  [ -f "$MANIFEST" ]
}

@test "manifest has required top-level key: id" {
  grep -Eq '^[[:space:]]*id[[:space:]]*=[[:space:]]*"openlogi\.herdr-mouse"' "$MANIFEST"
}

@test "manifest has required top-level key: name" {
  grep -Eq '^[[:space:]]*name[[:space:]]*=[[:space:]]*"OpenLogi Mouse"' "$MANIFEST"
}

@test "manifest has required top-level key: version" {
  grep -Eq '^[[:space:]]*version[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST"
}

@test "manifest has required top-level key: min_herdr_version" {
  grep -Eq '^[[:space:]]*min_herdr_version[[:space:]]*=[[:space:]]*"0\.7\.0"' "$MANIFEST"
}

@test "manifest has required top-level key: description" {
  grep -Eq '^[[:space:]]*description[[:space:]]*=[[:space:]]*".+"' "$MANIFEST"
}

@test "manifest has required top-level key: platforms" {
  grep -Eq '^[[:space:]]*platforms[[:space:]]*=[[:space:]]*\["macos",[[:space:]]*"linux"\]' "$MANIFEST"
}

@test "manifest declares no [[build]]" {
  ! grep -Eq '^[[:space:]]*\[\[build\]\]' "$MANIFEST"
}

@test "manifest declares one [[startup]]" {
  count="$(grep -c '^\[\[startup\]\]' "$MANIFEST" || true)"
  [ "$count" -eq 1 ]
}

@test "manifest startup command is scripts/bootstrap.sh" {
  grep -Fq 'command = ["scripts/bootstrap.sh"]' "$MANIFEST"
  [ -x "$REPO_ROOT/scripts/bootstrap.sh" ]
}

@test "manifest declares ten [[actions]] (nine Dispatcher + configure)" {
  count="$(grep -c '^\[\[actions\]\]' "$MANIFEST" || true)"
  [ "$count" -eq 10 ]
}

@test "manifest declares configure action and pane (popup 80%)" {
  grep -Eq '^[[:space:]]*id[[:space:]]*=[[:space:]]*"configure"' "$MANIFEST"
  grep -Fq 'bin/herdr-mouse-tui' "$MANIFEST"
  grep -Fq 'placement = "popup"' "$MANIFEST"
  grep -Fq 'width = "80%"' "$MANIFEST"
  grep -Fq 'height = "80%"' "$MANIFEST"
  # no default keys.command shipped
  ! grep -Eq '^[[:space:]]*\[\[keys\.command\]\]' "$MANIFEST"
}

@test "manifest declares all nine Dispatcher subcommands" {
  for sub in focus-left focus-right focus-up focus-down zoom-toggle next-tab prev-tab next-workspace prev-workspace; do
    grep -Fq "\"$sub\"" "$MANIFEST"
  done
}

@test "every action/pane command starts with bin/herdr-mouse" {
  # Total: 10 actions + 1 pane + 1 startup = 12; all bin/herdr-mouse* + 1 bootstrap
  total="$(grep -c '^[[:space:]]*command[[:space:]]*=' "$MANIFEST" || true)"
  ok="$(grep -c 'command[[:space:]]*=[[:space:]]*\["bin/herdr-mouse' "$MANIFEST" || true)"
  startup="$(grep -c 'command[[:space:]]*=[[:space:]]*\["scripts/bootstrap.sh"' "$MANIFEST" || true)"
  [ "$total" -eq 12 ]
  [ "$ok" -eq 11 ]
  [ "$startup" -eq 1 ]
}

@test "every action argv[0] resolves to an executable inside the repo" {
  # Extract first argv element from each command line and verify it is executable.
  while IFS= read -r line; do
    # Pull first quoted string inside the array brackets.
    argv0="$(printf '%s\n' "$line" | sed -n 's/.*\[\s*"\([^"]*\)".*/\1/p')"
    [ -n "$argv0" ]
    # Must be a repo-relative path.
    case "$argv0" in
      /*) echo "argv[0] must be repo-relative, got: $argv0" >&2; false ;;
    esac
    if [ ! -x "$REPO_ROOT/$argv0" ]; then
      echo "argv[0] not executable: $REPO_ROOT/$argv0 (from: $line)" >&2
      false
    fi
  done < <(grep '^[[:space:]]*command[[:space:]]*=' "$MANIFEST")
}

@test "every expected action id is present" {
  for id in focus-left focus-right focus-up focus-down zoom-toggle next-tab prev-tab next-workspace prev-workspace; do
    grep -Eq "^[[:space:]]*id[[:space:]]*=[[:space:]]*\"$id\"" "$MANIFEST"
  done
}
