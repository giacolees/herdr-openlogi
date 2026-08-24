#!/bin/sh
# bootstrap — herdr plugin startup hook (Bootstrap)
# POSIX sh only. Idempotently symlinks $HOME/.local/bin/herdr-mouse →
# $HERDR_PLUGIN_ROOT/bin/herdr-mouse. Silent no-op per
# docs/adr/0001-silent-no-op-contract.md: exit 0 with no stdout when
# HERDR_PLUGIN_ROOT is unset, the target is absent, or the symlink is
# already correct. Retargets if the symlink points elsewhere.
set -eu

if [ -z "${HERDR_PLUGIN_ROOT:-}" ]; then
  exit 0
fi

target="${HERDR_PLUGIN_ROOT}/bin/herdr-mouse"

if [ ! -e "$target" ]; then
  exit 0
fi

# HOME must be set to resolve the link path; otherwise silent no-op.
if [ -z "${HOME:-}" ]; then
  exit 0
fi

link="${HOME}/.local/bin/herdr-mouse"
dir=$(dirname "$link")

if [ ! -d "$dir" ]; then
  mkdir -p "$dir" 2>/dev/null || exit 0
fi

# If symlink already points at the correct target, nothing to do.
if [ -L "$link" ]; then
  current=$(readlink "$link" 2>/dev/null || true)
  if [ "$current" = "$target" ]; then
    exit 0
  fi
fi

# Remove stale file/symlink so ln can retarget. If it's a real directory
# (should not happen), leave it alone and no-op.
if [ -e "$link" ] || [ -L "$link" ]; then
  if [ -d "$link" ] && [ ! -L "$link" ]; then
    exit 0
  fi
  rm -f "$link" 2>/dev/null || exit 0
fi

ln -s "$target" "$link" 2>/dev/null || true
exit 0
