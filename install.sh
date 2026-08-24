#!/bin/sh
# install.sh — verify and patch the OpenLogi Binding overlay for openlogi-herdr
# POSIX sh only. Idempotent. Never edits ~/.config/openlogi/config.toml
# except via --apply (backup, idempotent). Symlink at
# ~/.local/bin/herdr-mouse is owned by the Bootstrap startup hook
# (scripts/bootstrap.sh), not this script — --check reports it
# informationally only.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_BIN="$SCRIPT_DIR/bin/herdr-mouse"
REF_SNIPPET="$SCRIPT_DIR/openlogi/per-app-bindings.toml"
DEST="$HOME/.local/bin/herdr-mouse"
CONFIG="$HOME/.config/openlogi/config.toml"

usage() {
	cat <<'USAGE'
Usage: ./install.sh --check | --apply [--device <key>] [--help]

  --check    Verify OpenLogi per_app_bindings block; report symlink status informationally
             (symlink at ~/.local/bin/herdr-mouse is owned by the Bootstrap startup hook)
  --apply    Patch ~/.config/openlogi/config.toml with the overlay (backup, idempotent)
             --device <key>  Explicit device key when auto-detect is ambiguous
  --help     Show this help

Symlink is owned by the Bootstrap startup hook (scripts/bootstrap.sh);
install.sh never creates it — --check only reports its status.
USAGE
}

get_overlay_body() {
	# Print the binding lines to insert under the per_app_bindings header.
	# Prefer the canonical reference file so the snippet stays single-source-of-truth;
	# strip the leading comment header (everything before the first binding) so the
	# inserted block is clean TOML. Fall back to inline heredoc.
	if [ -f "$REF_SNIPPET" ]; then
		if grep -q '^Back = ' "$REF_SNIPPET" 2>/dev/null; then
			sed -n '/^Back = /,$ p' "$REF_SNIPPET"
		else
			cat "$REF_SNIPPET"
		fi
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

detect_device() {
	# Resolve the device key to patch. Priority: explicit --device flag,
	# then selected_device in config, then single unique [devices."..."] key.
	# Prints the key to stdout; on failure prints Fix: hint to stderr and returns 1.
	explicit_device="$1"
	if [ -n "$explicit_device" ]; then
		printf '%s' "$explicit_device"
		return 0
	fi
	if [ -f "$CONFIG" ]; then
		sel=$(grep -E '^[[:space:]]*selected_device[[:space:]]*=' "$CONFIG" 2>/dev/null | head -n 1 | sed -E 's/^[[:space:]]*selected_device[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' 2>/dev/null || true)
		# sed returns the original line when no match; detect that
		if printf '%s' "$sel" | grep -q 'selected_device' 2>/dev/null; then
			sel=""
		fi
		if [ -n "$sel" ]; then
			printf '%s' "$sel"
			return 0
		fi
		# No selected_device — inspect unique [devices."key"] entries
		keys=$(grep -E '^\[devices\."[^"]+"' "$CONFIG" 2>/dev/null | sed -E 's/^\[devices\."([^"]+)".*/\1/' 2>/dev/null | sort -u 2>/dev/null || true)
		if [ -z "$keys" ]; then
			printf 'Error: cannot detect device — no [devices."..."] entries found in %s\n' "$CONFIG" >&2
			printf 'Fix: run ./install.sh --apply --device "<your-device-key>"\n' >&2
			printf 'Hint: find your device key with: grep selected_device %s\n' "$CONFIG" >&2
			return 1
		fi
		# Count unique keys (handle single-line and multi-line)
		num=$(printf '%s\n' "$keys" | grep -cve '^[[:space:]]*$' 2>/dev/null || printf '0')
		# wc-based fallback for portability when grep -cve behaves differently
		if [ "$num" -eq 0 ]; then
			num=$(printf '%s\n' "$keys" | wc -l | tr -d ' ' 2>/dev/null || printf '1')
		fi
		if [ "$num" -eq 1 ]; then
			single=$(printf '%s\n' "$keys" | head -n 1)
			printf '%s' "$single"
			return 0
		else
			printf 'Error: multiple devices found in %s — ambiguous which to patch\n' "$CONFIG" >&2
			printf '%s\n' "$keys" >&2
			printf 'Fix: run ./install.sh --apply --device "<your-device-key>"\n' >&2
			printf 'Hint: choose one of the keys above, or set selected_device in %s\n' "$CONFIG" >&2
			return 1
		fi
	else
		printf 'Error: OpenLogi config not found: %s\n' "$CONFIG" >&2
		printf 'Fix: ensure OpenLogi has run once, or run ./install.sh --apply --device "<your-device-key>" to create it\n' >&2
		return 1
	fi
}

do_apply() {
	explicit_device="${1:-}"
	device_key=$(detect_device "$explicit_device") || exit 1
	header="[devices.\"$device_key\".per_app_bindings.\"com.mitchellh.ghostty\"]"

	# Ensure config directory exists
	mkdir -p "$(dirname -- "$CONFIG")"

	# --- backup before write ---
	ts=$(date +%Y%m%d%H%M%S 2>/dev/null || date +%s 2>/dev/null || printf 'unknown')
	backup="${CONFIG}.bak.${ts}"
	i=0
	while [ -e "$backup" ]; do
		i=$((i + 1))
		backup="${CONFIG}.bak.${ts}.${i}"
	done
	if [ -f "$CONFIG" ]; then
		if cp -p -- "$CONFIG" "$backup" 2>/dev/null || cp -- "$CONFIG" "$backup" 2>/dev/null; then
			printf 'Backup created: %s\n' "$backup"
		else
			printf 'Error: failed to create backup %s\n' "$backup" >&2
			exit 1
		fi
	else
		printf 'No existing config at %s — creating new file\n' "$CONFIG"
		: > "$backup" 2>/dev/null || true
		if [ -f "$backup" ]; then
			printf 'Backup created: %s (empty original)\n' "$backup"
		fi
	fi

	# Build overlay temp file: header + body
	tmp_overlay=$(mktemp 2>/dev/null || mktemp /tmp/herdr_overlay.XXXXXX)
	tmp_new=$(mktemp 2>/dev/null || mktemp /tmp/herdr_new.XXXXXX)
	printf '%s\n' "$header" > "$tmp_overlay"
	get_overlay_body >> "$tmp_overlay"

	if [ -f "$CONFIG" ]; then
		# Idempotent insert-or-replace: replace existing block or append
		found=0
		in_target=0
		need_append=1
		: > "$tmp_new"
		while IFS= read -r line || [ -n "$line" ]; do
			if [ "$line" = "$header" ]; then
				if [ "$found" -eq 0 ]; then
					found=1
					need_append=0
					in_target=1
					cat "$tmp_overlay" >> "$tmp_new"
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
						printf '%s\n' "$line" >> "$tmp_new"
						;;
					*)
						continue
						;;
				esac
			else
				printf '%s\n' "$line" >> "$tmp_new"
			fi
		done < "$CONFIG"
		if [ "$need_append" -eq 1 ]; then
			if [ -s "$tmp_new" ]; then
				printf '\n' >> "$tmp_new"
			fi
			cat "$tmp_overlay" >> "$tmp_new"
		fi
		if [ ! -s "$tmp_new" ]; then
			printf 'Error: generated config is empty, aborting\n' >&2
			rm -f "$tmp_overlay" "$tmp_new"
			exit 1
		fi
		# Atomic write via temp then move
		tmp_write="${CONFIG}.tmp.$$"
		if cat "$tmp_new" > "$tmp_write" 2>/dev/null; then
			mv -- "$tmp_write" "$CONFIG"
		else
			mv -- "$tmp_new" "$CONFIG"
		fi
		rm -f "$tmp_new" "$tmp_overlay" "$tmp_write" 2>/dev/null || true
		printf 'Patched: %s with %s\n' "$CONFIG" "$header"
	else
		cat "$tmp_overlay" > "$CONFIG"
		rm -f "$tmp_new" "$tmp_overlay" 2>/dev/null || true
		printf 'Created: %s with %s\n' "$CONFIG" "$header"
	fi

	printf '\nRunning --check...\n'
	do_check
}

print_reference_toml() {
	# Print the exact TOML the user should paste.
	# Prefer the canonical reference file when present so the snippet stays
	# single-source-of-truth; fall back to inline heredoc.
	if [ -f "$REF_SNIPPET" ]; then
		# Extract just the binding lines (skip the leading comment header)
		# but keep the commented optional Gesture lines so the user sees them.
		# The reference file already contains the device-key-agnostic comment.
		printf '\n'
		cat "$REF_SNIPPET"
		printf '\n'
	else
		cat <<'TOML'

# Paste under [devices."<your-device-key>".per_app_bindings."com.mitchellh.ghostty"]
# in ~/.config/openlogi/config.toml. Find your device key next to `selected_device`.

Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }
Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }
GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }
DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }

# Gesture pad directions (add if your device exposes them and you want up/down focus):
# GestureUp   = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-up" }
# GestureDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-down" }
TOML
	fi
}

do_check() {
	status=0

	# --- symlink status (informational only; owned by Bootstrap startup hook) ---
	if [ ! -L "$DEST" ]; then
		if [ -e "$DEST" ]; then
			printf 'INFO: %s exists but is not a symlink\n' "$DEST"
			printf 'INFO: symlink is owned by the Bootstrap startup hook (scripts/bootstrap.sh)\n'
		else
			printf 'INFO: symlink not present: %s (Bootstrap startup hook will create it on next herdr session start)\n' "$DEST"
		fi
	else
		target=$(readlink "$DEST" 2>/dev/null || true)
		if [ "$target" != "$REPO_BIN" ]; then
			printf 'INFO: symlink points elsewhere: %s -> %s\n' "$DEST" "$target"
			printf 'INFO: expected %s -> %s (managed by Bootstrap startup hook)\n' "$DEST" "$REPO_BIN"
		else
			printf 'OK: symlink %s -> %s\n' "$DEST" "$REPO_BIN"
		fi
	fi

	# --- check OpenLogi config ---
	if [ ! -f "$CONFIG" ]; then
		printf 'FAIL: OpenLogi config not found: %s\n' "$CONFIG" >&2
		printf 'Fix: ensure OpenLogi has run once, then add the per_app_bindings block:\n' >&2
		printf '  File: %s\n' "$CONFIG" >&2
		print_reference_toml >&2
		status=1
	else
		# Check for per_app_bindings."com.mitchellh.ghostty" section header (device-key agnostic)
		if ! grep -q 'per_app_bindings\."com\.mitchellh\.ghostty"' "$CONFIG" 2>/dev/null; then
			printf 'FAIL: per_app_bindings."com.mitchellh.ghostty" block not found in %s\n' "$CONFIG" >&2
			printf 'Fix: add the following under [devices."<your-device-key>".per_app_bindings."com.mitchellh.ghostty"] in %s:\n' "$CONFIG" >&2
			print_reference_toml >&2
			status=1
		else
			# Validate required bindings exist with correct dispatcher form.
			# The reference snippet uses "$HOME/.local/bin/herdr-mouse <action>" (space).
			# Legacy slash form ("$HOME/.local/bin/herdr-mouse/focus-left") is considered wrong
			# because after symlink that path no longer exists.
			missing=""
			# --- check config block (bindings contain literal $HOME — never expand) ---
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }' "$CONFIG"; then
				missing="${missing}  - Back -> focus-left\n"
			fi
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }' "$CONFIG"; then
				missing="${missing}  - Forward -> focus-right\n"
			fi
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }' "$CONFIG"; then
				missing="${missing}  - GestureButton -> zoom-toggle\n"
			fi
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }' "$CONFIG"; then
				missing="${missing}  - DpiToggle -> next-tab\n"
			fi
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }' "$CONFIG"; then
				missing="${missing}  - ThumbwheelScrollUp -> prev-workspace\n"
			fi
			# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
			if ! grep -Fq 'ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }' "$CONFIG"; then
				missing="${missing}  - ThumbwheelScrollDown -> next-workspace\n"
			fi

			if [ -n "$missing" ]; then
				printf 'FAIL: OpenLogi config has per_app_bindings block but required bindings are missing or incorrect:\n' >&2
				printf '%b' "$missing" >&2
				printf 'Expected bindings (exact lines to have in the block):\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  Back = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-left" }\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  Forward = { RunShellCommand = "$HOME/.local/bin/herdr-mouse focus-right" }\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  GestureButton = { RunShellCommand = "$HOME/.local/bin/herdr-mouse zoom-toggle" }\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  DpiToggle = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-tab" }\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  ThumbwheelScrollUp = { RunShellCommand = "$HOME/.local/bin/herdr-mouse prev-workspace" }\n' >&2
				# shellcheck disable=SC2016 # intentional: $HOME must stay literal in TOML
				printf '  ThumbwheelScrollDown = { RunShellCommand = "$HOME/.local/bin/herdr-mouse next-workspace" }\n' >&2
				printf '\nFix: ensure %s contains:\n' "$CONFIG" >&2
				print_reference_toml >&2
				status=1
			else
				printf 'OK: OpenLogi config %s contains per_app_bindings."com.mitchellh.ghostty" with required bindings\n' "$CONFIG"
			fi
		fi
	fi

	if [ "$status" -eq 0 ]; then
		printf 'All checks passed.\n'
		return 0
	else
		return 1
	fi
}

case "${1:-}" in
--check)
	do_check
	;;
--apply)
	shift
	apply_device=""
	while [ $# -gt 0 ]; do
		case "$1" in
		--device)
			if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
				printf 'Error: --device requires an argument\n' >&2
				usage >&2
				exit 1
			fi
			apply_device="$2"
			shift 2
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			printf 'Unknown argument for --apply: %s\n' "$1" >&2
			usage >&2
			exit 1
			;;
		esac
	done
	do_apply "$apply_device"
	;;
--help | -h)
	usage
	;;
"")
	usage >&2
	exit 1
	;;
*)
	printf 'Unknown argument: %s\n' "$1" >&2
	usage >&2
	exit 1
	;;
esac
