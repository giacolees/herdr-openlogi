# Silent no-op failure contract

Every `bin/herdr-mouse` invocation exits 0 with no output when herdr is unreachable or the requested move is impossible; debug output is opt-in via `HERDR_MOUSE_DEBUG=1` to stderr only. We chose this over surfacing errors because mouse actions fire at high frequency and any notification or non-zero exit would spam the user. The trade-off is invisibility of failures — mitigated by `install.sh --check` and debug mode being loud and documented.
