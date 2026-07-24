#!/usr/bin/env bash
# tl-escalate.sh — surface an actionable decision to the owner in the terminal (§2.3, D8).
# Every ask states its default. Park, don't block: if the owner does not answer within the ask's
# timeout, the stated default fires and is logged — owner silence is safe, not a deadlock.
#
# It records the decision to data/<id>/decision (the worker polls that) and logs to the escalation
# log. It deliberately does NOT append to the worker's .status event log, so a silently-resuming
# worker leaves a stale tail — exactly the case tl-state.sh is built to reconcile.
# tl: inline read blocks the watcher up to `timeout`s — fine for a co-present owner; make it an
#     async pending-ask queue when escalation moves off the terminal (Slack, Phase 2).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-escalate ID}"
ask="$TL_DATA/$id/ask"
[ -f "$ask" ] || tl_die "no pending ask for $id"

get() { awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ask"; }
question="$(get question)"; default="$(get default)"; timeout="$(get timeout)"; timeout="${timeout:-30}"

printf 'tl: DECISION NEEDED [%s] %s  (default: %s in %ss)\n' "$id" "$question" "$default" "$timeout" >&2

ans=""
if [ -n "${TL_DECISION:-}" ]; then ans="$TL_DECISION"           # non-interactive override (tests/scripts)
elif [ -t 0 ]; then read -r -t "$timeout" ans || ans=""; fi     # co-present owner
[ -z "$ans" ] && ans="$default"                                 # park-don't-block: default fires

printf '%s\n' "$ans" > "$TL_DATA/$id/decision"
printf '%s\tresolved\t%s\n' "$(tl_now)" "$ans" >> "$TL_DATA/$id/escalation.log"
tl_log "escalation [$id] resolved: $ans"
