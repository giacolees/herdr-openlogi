# Manual overlay by default, opt-in --apply patching

`install.sh` never auto-edits `~/.config/openlogi/config.toml` by default; it only verifies via `--check` and prints the exact TOML to paste. An opt-in `--apply` flag patches the file with a timestamped backup and idempotent insert-or-replace. We chose manual default because OpenLogi owns `config.toml` and can overwrite it, so silent auto-edits risk corrupting user configuration or being lost on update; the opt-in gives convenience without making auto-mutation the default path.

Considered Options: always auto-patch on `./install.sh`; never offer auto-patch; require `python3`/`taplo` for TOML-aware patching. Rejected because always auto-patch is unsafe, never auto-patch leaves friction for new users, and a parser dependency violates the POSIX `sh` constraint.
