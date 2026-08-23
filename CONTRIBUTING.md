# Contributing

Thanks for helping improve `herdr-openlogi`.

## Development setup

```sh
git clone <this-repo-url> herdr-openlogi
cd herdr-openlogi
brew install shellcheck bats-core jq   # macOS
```

No new runtime dependencies — `bin/herdr-mouse` and `install.sh` are POSIX `sh` only.

## Checks

Run before every commit / PR:

```sh
# Lint (must be clean)
shellcheck bin/herdr-mouse install.sh
sh -n bin/herdr-mouse
sh -n install.sh

# Tests (bats)
bats tests/

# Installer smoke check (fixture HOME)
HOME=$(mktemp -d) ./install.sh --check          # should fail without fixture
./install.sh --check                             # should pass on a configured machine
```

`bats` mocks `HERDR_BIN`/`JQ_BIN` so you don't need a running herdr server to exercise the 7 dispatcher actions and the silent no-op branches.

## PR flow

1. Fork and create a feature branch from `main`.
2. Keep changes focused and POSIX-`sh` clean (`shellcheck` must pass).
3. Add or update `bats` tests for dispatcher / installer changes.
4. Update `CHANGELOG.md` under `## [Unreleased]`.
5. Open a PR against `main` — CI must pass (`shellcheck`, `sh -n`, `bats`, `install.sh --check`).

For questions, open an issue with the output of `./install.sh --check`.
