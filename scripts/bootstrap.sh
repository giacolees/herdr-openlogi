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

# Helpers (duplicated from install.sh, kept self-contained for the managed checkout)
_keybinding_config="${HOME}/.config/openlogi-herdr/config.toml"
_valid_inputs="Back Forward GestureButton DpiToggle ThumbwheelScrollUp ThumbwheelScrollDown GestureUp GestureDown"
_valid_actions="focus-left focus-right focus-up focus-down zoom-toggle next-tab prev-tab next-workspace prev-workspace"

_bootstrap_is_valid_input() {
	case " $_valid_inputs " in
	*" $1 "*) return 0 ;;
	*) return 1 ;;
	esac
}

_bootstrap_is_valid_action() {
	case " $_valid_actions " in
	*" $1 "*) return 0 ;;
	*) return 1 ;;
	esac
}

_bootstrap_get_effective_action() {
	_bge_input="$1"
	_bge_default="$2"
	if [ ! -f "$_keybinding_config" ]; then
		printf '%s' "$_bge_default"
		return 0
	fi
	_bge_found=""
	_bge_in_section=0
	while IFS= read -r _bge_raw || [ -n "$_bge_raw" ]; do
		_bge_line=$(printf '%s' "$_bge_raw" | tr -d '\r' 2>/dev/null || printf '%s' "$_bge_raw")
		_bge_trim=$(printf '%s' "$_bge_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$_bge_line")
		case "$_bge_trim" in
		"" | \#*) continue ;;
		esac
		case "$_bge_trim" in
		\[*\]*)
			_bge_sec=$(printf '%s' "$_bge_trim" | sed 's/[[:space:]]*#.*//' 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$_bge_trim")
			if [ "$_bge_sec" = "[keybindings]" ]; then
				_bge_in_section=1
			else
				_bge_in_section=0
			fi
			continue
			;;
		esac
		if [ "$_bge_in_section" -eq 0 ]; then
			continue
		fi
		_bge_no_comment=$(printf '%s' "$_bge_line" | sed 's/#.*//' 2>/dev/null || printf '%s' "$_bge_line")
		_bge_stripped=$(printf '%s' "$_bge_no_comment" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$_bge_no_comment")
		case "$_bge_stripped" in
		"" | \#*) continue ;;
		*"="*) ;;
		*) continue ;;
		esac
		_bge_key=$(printf '%s' "$_bge_stripped" | sed -E 's/^([^=]+)=.*/\1/' 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$_bge_stripped")
		if [ "$_bge_key" != "$_bge_input" ]; then
			continue
		fi
		_bge_val_raw=$(printf '%s' "$_bge_stripped" | sed -E 's/^[^=]*=[[:space:]]*//' 2>/dev/null || printf '')
		_bge_val_trim=$(printf '%s' "$_bge_val_raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$_bge_val_raw")
		_bge_first=$(printf '%s' "$_bge_val_trim" | cut -c1 2>/dev/null || printf '%s' "$_bge_val_trim" | sed 's/^\(.\)/\1/' 2>/dev/null || true)
		if [ "$_bge_first" = '"' ]; then
			_bge_val=$(printf '%s' "$_bge_val_trim" | sed -E 's/^"([^"]*)".*/\1/' 2>/dev/null || printf '')
		elif [ "$_bge_first" = "'" ]; then
			_bge_val=$(printf '%s' "$_bge_val_trim" | sed -E "s/^'([^']*)'.*/\1/" 2>/dev/null || printf '')
		else
			_bge_val=$(printf '%s' "$_bge_val_trim" | sed -E 's/[[:space:]].*//' 2>/dev/null || printf '%s' "$_bge_val_trim")
		fi
		if _bootstrap_is_valid_input "$_bge_key" 2>/dev/null && [ -n "$_bge_val" ] && _bootstrap_is_valid_action "$_bge_val" 2>/dev/null; then
			_bge_found="$_bge_val"
		fi
	done < "$_keybinding_config" 2>/dev/null || true
	if [ -n "$_bge_found" ]; then
		printf '%s' "$_bge_found" 2>/dev/null || printf '%s' "$_bge_default"
	else
		printf '%s' "$_bge_default" 2>/dev/null || true
	fi
}

_bootstrap_get_overlay_body() {
	_b_body_back=$(_bootstrap_get_effective_action "Back" "focus-left" 2>/dev/null || printf 'focus-left')
	_b_body_forward=$(_bootstrap_get_effective_action "Forward" "focus-right" 2>/dev/null || printf 'focus-right')
	_b_body_gesture_button=$(_bootstrap_get_effective_action "GestureButton" "zoom-toggle" 2>/dev/null || printf 'zoom-toggle')
	_b_body_dpi=$(_bootstrap_get_effective_action "DpiToggle" "next-tab" 2>/dev/null || printf 'next-tab')
	_b_body_up=$(_bootstrap_get_effective_action "ThumbwheelScrollUp" "prev-workspace" 2>/dev/null || printf 'prev-workspace')
	_b_body_down=$(_bootstrap_get_effective_action "ThumbwheelScrollDown" "next-workspace" 2>/dev/null || printf 'next-workspace')
	_b_body_gup=$(_bootstrap_get_effective_action "GestureUp" "" 2>/dev/null || printf '')
	_b_body_gdown=$(_bootstrap_get_effective_action "GestureDown" "" 2>/dev/null || printf '')
	# shellcheck disable=SC2016
	printf 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_back"
	# shellcheck disable=SC2016
	printf 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_forward"
	# shellcheck disable=SC2016
	printf 'GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_gesture_button"
	# shellcheck disable=SC2016
	printf 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_dpi"
	# shellcheck disable=SC2016
	printf 'ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_up"
	# shellcheck disable=SC2016
	printf 'ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_down"
	if [ -n "$_b_body_gup" ]; then
		# shellcheck disable=SC2016
		printf 'GestureUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_gup"
	fi
	if [ -n "$_b_body_gdown" ]; then
		# shellcheck disable=SC2016
		printf 'GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse %s" }\n' "$_b_body_gdown"
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

# Already has correct block? Then nothing to do (idempotent) — check effective mapping
_eff_back=$(_bootstrap_get_effective_action "Back" "focus-left" 2>/dev/null || printf 'focus-left')
_eff_forward=$(_bootstrap_get_effective_action "Forward" "focus-right" 2>/dev/null || printf 'focus-right')
_eff_gesture_button=$(_bootstrap_get_effective_action "GestureButton" "zoom-toggle" 2>/dev/null || printf 'zoom-toggle')
_eff_dpi=$(_bootstrap_get_effective_action "DpiToggle" "next-tab" 2>/dev/null || printf 'next-tab')
_eff_up=$(_bootstrap_get_effective_action "ThumbwheelScrollUp" "prev-workspace" 2>/dev/null || printf 'prev-workspace')
_eff_down=$(_bootstrap_get_effective_action "ThumbwheelScrollDown" "next-workspace" 2>/dev/null || printf 'next-workspace')
_eff_gup=$(_bootstrap_get_effective_action "GestureUp" "" 2>/dev/null || printf '')
_eff_gdown=$(_bootstrap_get_effective_action "GestureDown" "" 2>/dev/null || printf '')
if [ -f "$openlogi_config" ] \
	&& grep -q 'per_app_bindings\."com\.mitchellh\.ghostty"' "$openlogi_config" 2>/dev/null \
	&& grep -Fq "Back = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_back\" }" "$openlogi_config" 2>/dev/null \
	&& grep -Fq "Forward = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_forward\" }" "$openlogi_config" 2>/dev/null \
	&& grep -Fq "GestureButton = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_gesture_button\" }" "$openlogi_config" 2>/dev/null \
	&& grep -Fq "DpiToggle = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_dpi\" }" "$openlogi_config" 2>/dev/null \
	&& grep -Fq "ThumbwheelScrollUp = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_up\" }" "$openlogi_config" 2>/dev/null \
	&& grep -Fq "ThumbwheelScrollDown = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_down\" }" "$openlogi_config" 2>/dev/null; then
	_gup_ok=1
	_gdown_ok=1
	if [ -n "$_eff_gup" ]; then
		if ! grep -Fq "GestureUp = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_gup\" }" "$openlogi_config" 2>/dev/null; then
			_gup_ok=0
		fi
	fi
	if [ -n "$_eff_gdown" ]; then
		if ! grep -Fq "GestureDown = { RunShellCommand = \"\$HOME/.local/bin/herdr-mouse $_eff_gdown\" }" "$openlogi_config" 2>/dev/null; then
			_gdown_ok=0
		fi
	fi
	if [ "$_gup_ok" -eq 1 ] && [ "$_gdown_ok" -eq 1 ]; then
		exit 0
	fi
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
