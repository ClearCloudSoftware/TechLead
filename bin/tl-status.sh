#!/usr/bin/env bash
# tl-status.sh — append ONE wake-worthy transition to a worker's event log (§3.4, §3.7).
# Workers call this only on transitions worth waking for (needs-decision, failed, done, paused).
# They write NOTHING on silent resume — that is what makes the log tail go stale, and why
# current-state reads must go through tl-state.sh, not `tail -1`.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-status ID VERB [detail]}"; verb="${2:?verb}"; shift 2 || true
printf '%s\t%s\t%s\n' "$(tl_now)" "$verb" "${*:-}" >> "$(tl_status_file "$id")"
