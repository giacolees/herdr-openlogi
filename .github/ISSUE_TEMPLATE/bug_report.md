---
name: Bug report
about: Something isn't working
title: "[bug] "
labels: bug
---

## Describe the bug

A clear description of what happened and what you expected.

## Environment

- macOS version:
- OpenLogi version:
- herdr version (`herdr status`):
- Mouse model / device key (`grep selected_device ~/.config/openlogi/config.toml`):

## Diagnostics

Please paste the full output of:

```sh
./install.sh --check
```

```sh
herdr status
```

```sh
grep -A 10 'per_app_bindings\."com.mitchellh.ghostty"' ~/.config/openlogi/config.toml
```

Also include `HERDR_MOUSE_DEBUG=1 ~/.local/bin/herdr-mouse focus-right 2>&1` if relevant.

## Additional context

Logs, steps to reproduce, or screenshots.
