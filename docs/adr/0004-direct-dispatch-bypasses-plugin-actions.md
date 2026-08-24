# Direct dispatch bypasses plugin actions

OpenLogi mouse clicks invoke `~/.local/bin/herdr-mouse` directly via the
Binding overlay — the Dispatcher — not via herdr plugin actions. The Plugin
manifest still wraps the same Dispatcher (`bin/herdr-mouse` per subcommand)
for packaging, discovery, and `herdr plugin install` marketplace listing.

We chose direct dispatch so the hot click path stays shell-fast and honours
the Silent no-op contract (ADR-0001) without an extra plugin-action
indirection; the plugin layer adds installability without touching runtime
latency. The trade-off is duplication — every Dispatcher subcommand appears
as a `[[actions]]` entry that clicks never exercise — mitigated by deriving
the action list from the `case "$cmd"` block in `bin/herdr-mouse` and
covering it with `tests/manifest.bats`.

Considered Options: route clicks through plugin actions (adds indirection
and latency); omit plugin actions entirely (loses herdr-side invocation and
marketplace action listing).
