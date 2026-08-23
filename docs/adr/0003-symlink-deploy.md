# Symlink deploy at ~/.local/bin/herdr-mouse

`install.sh` deploys `bin/herdr-mouse` as a symlink `~/.local/bin/herdr-mouse -> <repo>/bin/herdr-mouse`, not a copy. We chose a symlink so fixes are picked up without redeploy and the repo remains the single source of truth; a copy would diverge. The trade-off is the symlink breaks if the repo is moved — mitigated by `install.sh --check` detecting a stale target and re-running `install.sh` fixing it.
