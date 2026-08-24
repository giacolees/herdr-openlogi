# Startup Bootstrap owns the symlink

The Bootstrap startup hook (`scripts/bootstrap.sh`, declared as `[[startup]]`
in `herdr-plugin.toml`) idempotently symlinks
`~/.local/bin/herdr-mouse → $HERDR_PLUGIN_ROOT/bin/herdr-mouse`;
`install.sh` no longer creates or removes the symlink and `--check` reports
it informationally only.

We chose this so `herdr plugin install` self-deploys on session restore and
reinstall retargets automatically without a manual step. The trade-off is the
symlink may not exist before the first herdr session start, so early clicks
are a Silent no-op (per ADR-0001) — mitigated by Bootstrap running once after
session restore, being idempotent, and exiting 0 silently when
`HERDR_PLUGIN_ROOT` is unset or the target is absent.

Considered Options: keep symlink management in `install.sh` (requires a manual
post-install step for plugin installs); copy the Dispatcher instead of
symlinking (diverges from the repo source of truth).
