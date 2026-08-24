#!/bin/sh
# shellcheck disable=SC2016 # $HOME literal in TOML is intentional
# bootstrap — herdr plugin startup hook (Bootstrap)
# POSIX sh only. Idempotently symlinks $HOME/.local/bin/herdr-mouse →
# $HERDR_PLUGIN_ROOT/bin/herdr-mouse and, when opted in via
# $HERDR_PLUGIN_CONFIG_DIR/auto-apply, idempotently patches the OpenLogi
# overlay in ~/.config/openlogi/config.toml. Silent no-op per
# docs/adr/0001-silent-no-op-contract.md: exit 0 with no stdout when
# HERDR_PLUGIN_ROOT is unset, the target is absent, or HOME is unset.
# Overlay auto-patch is best-effort and silent — failures never break startup.
set -eu

# --- symlink deploy (always) ---
if [ -z "${HERDR_PLUGIN_ROOT:-}" ]; then
	exit 0
fi

target="${HERDR_PLUGIN_ROOT}/bin/herdr-mouse"

if [ ! -e "$target" ]; then
	exit 0
fi

if [ -z "${HOME:-}" ]; then
	exit 0
fi

link="${HOME}/.local/bin/herdr-mouse"
dir=$(dirname "$link")

if [ ! -d "$dir" ]; then
	mkdir -p "$dir" 2>/dev/null || exit 0
fi

needs_link=1
if [ -L "$link" ]; then
	current=$(readlink "$link" 2>/dev/null || true)
	if [ "$current" = "$target" ]; then
		needs_link=0
	fi
fi

if [ "$needs_link" -eq 1 ]; then
	if [ -e "$link" ] || [ -L "$link" ]; then
		if [ -d "$link" ] && [ ! -L "$link" ]; then
			: # directory — leave alone, but continue to overlay check
		else
			rm -f "$link" 2>/dev/null || true
			ln -s "$target" "$link" 2>/dev/null || true
		fi
	else
		ln -s "$target" "$link" 2>/dev/null || true
	fi
fi

# --- opt-in overlay auto-patch ---
# Enabled only when $HERDR_PLUGIN_CONFIG_DIR/auto-apply exists (empty file
# is enough; if the file contains a device key it is used as --device).
# This keeps the default install manual (ADR-0002) while allowing a lean
# one-command setup: `touch $(herdr plugin config-dir openlogi.herdr-mouse)/auto-apply`.
config_dir="${HERDR_PLUGIN_CONFIG_DIR:-}"
if [ -z "$config_dir" ] || [ ! -f "$config_dir/auto-apply" ]; then
	exit 0
fi

# Read explicit device from flag file if it contains a non-empty, non-comment line.
explicit_device=""
if [ -s "$config_dir/auto-apply" ]; then
	# first non-empty, non-# line
	explicit_device=$(grep -v '^[[:space:]]*#' "$config_dir/auto-apply" 2>/dev/null | grep -v '^[[:space:]]*$' 2>/dev/null | head -n 1 | tr -d '\r' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' 2>/dev/null || true)
fi

# Paths for overlay patch
openlogi_config="${HOME}/.config/openlogi/config.toml"
ref_snippet="${HERDR_PLUGIN_ROOT}/openlogi/per-app-bindings.toml"

# Helpers (duplicated from install.sh, kept self-contained for the managed checkout)
_bootstrap_get_overlay_body() {
	if [ -f "$ref_snippet" ] && grep -q '^Back = ' "$ref_snippet" 2>/dev/null; then
		sed -n '/^Back = /,$ p' "$ref_snippet" 2>/dev/null || cat "$ref_snippet" 2>/dev/null || true
	elif [ -f "$ref_snippet" ]; then
		cat "$ref_snippet" 2>/dev/null || true
	else
		cat <<'TOML'
Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }
Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }
GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }
DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }
ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }
ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }

# Gesture pad directions (add if your device exposes them and you want up/down focus):
# GestureUp   = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }
# GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }
TOML
	fi
}

_bootstrap_detect_device() {
	exp="$1"
	if [ -n "$exp" ]; then
		printf '%s' "$exp"
		return 0
	fi
	if [ -f "$openlogi_config" ]; then
		sel=$(grep -E '^[[:space:]]*selected_device[[:space:]]*=' "$openlogi_config" 2>/dev/null | head -n 1 | sed -E 's/^[[:space:]]*selected_device[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' 2>/dev/null || true)
		if printf '%s' "$sel" | grep -q 'selected_device' 2>/dev/null; then
			sel=""
		fi
		if [ -n "$sel" ]; then
			printf '%s' "$sel"
			return 0
		fi
		keys=$(grep -E '^\[devices\."[^"]+"' "$openlogi_config" 2>/dev/null | sed -E 's/^\[devices\."([^"]+)".*/\1/' 2>/dev/null | sort -u 2>/dev/null || true)
		if [ -z "$keys" ]; then
			return 1
		fi
		num=$(printf '%s\n' "$keys" | grep -cve '^[[:space:]]*$' 2>/dev/null || printf '0')
		if [ "$num" -eq 0 ]; then
			num=$(printf '%s\n' "$keys" | wc -l | tr -d ' ' 2>/dev/null || printf '1')
		fi
		if [ "$num" -eq 1 ]; then
			printf '%s' "$(printf '%s\n' "$keys" | head -n 1)"
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

# Best-effort patch — any failure is a silent no-op (never break startup)
device_key=$(_bootstrap_detect_device "$explicit_device" 2>/dev/null || true)
if [ -z "$device_key" ]; then
	exit 0
fi

header="[devices.\"$device_key\".per_app_bindings.\"com.mitchellh.ghostty\"]"

# Already has correct block? Then nothing to do (idempotent)
if [ -f "$openlogi_config" ] \
	&& grep -q 'per_app_bindings\."com\.mitchellh\.ghostty"' "$openlogi_config" 2>/dev/null \
	&& grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$openlogi_config" 2>/dev/null \
	&& grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$openlogi_config" 2>/dev/null \
	&& grep -Fq 'GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$openlogi_config" 2>/dev/null; then
	exit 0
fi

# Ensure config dir exists
mkdir -p "$(dirname -- "$openlogi_config")" 2>/dev/null || exit 0

# Backup
ts=$(date +%Y%m%d%H%M%S 2>/dev/null || date +%s 2>/dev/null || printf 'unknown')
backup="${openlogi_config}.bak.${ts}"
i=0
while [ -e "$backup" ]; do
	i=$((i + 1))
	backup="${openlogi_config}.bak.${ts}.${i}"
done
if [ -f "$openlogi_config" ]; then
	cp -p -- "$openlogi_config" "$backup" 2>/dev/null || cp -- "$openlogi_config" "$backup" 2>/dev/null || true
else
	: > "$backup" 2>/dev/null || true
fi

tmp_overlay=$(mktemp 2>/dev/null || mktemp /tmp/herdr_overlay.XXXXXX 2>/dev/null || printf '/tmp/herdr_overlay.$$')
tmp_new=$(mktemp 2>/dev/null || mktemp /tmp/herdr_new.XXXXXX 2>/dev/null || printf '/tmp/herdr_new.$$')
# shellcheck disable=SC2064
trap 'rm -f "$tmp_overlay" "$tmp_new" 2>/dev/null || true' EXIT 2>/dev/null || true
printf '%s\n' "$header" > "$tmp_overlay" 2>/dev/null || exit 0
_bootstrap_get_overlay_body >> "$tmp_overlay" 2>/dev/null || exit 0

if [ -f "$openlogi_config" ]; then
	found=0
	in_target=0
	need_append=1
	: > "$tmp_new" 2>/dev/null || exit 0
	while IFS= read -r line || [ -n "$line" ]; do
		if [ "$line" = "$header" ]; then
			if [ "$found" -eq 0 ]; then
				found=1
				need_append=0
				in_target=1
				cat "$tmp_overlay" >> "$tmp_new" 2>/dev/null || true
				continue
			else
				in_target=1
				continue
			fi
		fi
		if [ "$in_target" -eq 1 ]; then
			case "$line" in
				\[*)
					in_target=0
					printf '%s\n' "$line" >> "$tmp_new" 2>/dev/null || true
					;;
				*)
					continue
					;;
			esac
		else
			printf '%s\n' "$line" >> "$tmp_new" 2>/dev/null || true
		fi
	done < "$openlogi_config"
	if [ "$need_append" -eq 1 ]; then
		if [ -s "$tmp_new" ]; then
			printf '\n' >> "$tmp_new" 2>/dev/null || true
		fi
		cat "$tmp_overlay" >> "$tmp_new" 2>/dev/null || true
	fi
	if [ ! -s "$tmp_new" ]; then
		exit 0
	fi
	tmp_write="${openlogi_config}.tmp.$$"
	if cat "$tmp_new" > "$tmp_write" 2>/dev/null; then
		mv -- "$tmp_write" "$openlogi_config" 2>/dev/null || mv -- "$tmp_new" "$openlogi_config" 2>/dev/null || true
	else
		mv -- "$tmp_new" "$openlogi_config" 2>/dev/null || true
	fi
	rm -f "$tmp_new" "$tmp_overlay" "$tmp_write" 2>/dev/null || true
else
	cat "$tmp_overlay" > "$openlogi_config" 2>/dev/null || true
	rm -f "$tmp_new" "$tmp_overlay" 2>/dev/null || true
fi

exit 0
