# openlogi-herdr

Canonizes the ad-hoc Logitech mouse → herdr integration into a versioned repo: a single dispatcher gated by the OpenLogi binding overlay that fires only while Ghostty is focused.

## Language

**Binding overlay**:
OpenLogi's per-application sparse action map (`per_app_bindings."com.mitchellh.ghostty"`) that replaces default button actions only while Ghostty has focus.
_Avoid_: per-app bindings block, overlay config

**Dispatcher**:
The single POSIX `sh` executable (`bin/herdr-mouse`) that translates each mouse input into a herdr socket-API call; one artifact, seven subcommands.
_Avoid_: action script, handler, driver

**Silent no-op**:
Failure contract of every dispatcher invocation: if herdr is unreachable or the move is impossible, exit 0 with no stdout, stderr, or notification.
_Avoid_: silent failure, quiet error

**Directional focus**:
Moving pane focus one step in a cardinal direction within the current herdr layout.
_Avoid_: pane navigation, directional move

**Tab cycle**:
Switching to the next or previous tab of the focused workspace, wrapping at the ends.
_Avoid_: tab switch, tab rotation

**Workspace cycle**:
Switching to the next or previous workspace, wrapping at the ends.
_Avoid_: workspace switch

**Zoom toggle**:
Expanding or collapsing the focused herdr pane.
_Avoid_: pane zoom, maximize

**Canonization**:
Promoting the ad-hoc deployed setup (hand-edited TOML, legacy scripts) into this versioned repo as source of truth.
_Avoid_: migration, formalization
