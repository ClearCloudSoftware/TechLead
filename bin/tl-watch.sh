#!/usr/bin/env bash
# tl-watch.sh — the zero-token supervisor (§3.3). It blocks on the fleet by cheap OS polling
# (kill -0 and stat are ~free — no LLM), classifies every task through tl-state + the policy
# table, and wakes the lead ONLY on actionable events. An idle crew costs nothing.
#
# Durability (§3.3): an actionable wake is appended to state/.wake-queue BEFORE anything visible
# or irreversible happens, so a crash mid-handling is recoverable by draining the queue.
# tl: poll loop, interval TL_WATCH_INTERVAL — stat/kill -0 are cheap; move to fs-events if the
#     fleet grows past a handful.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-policy.sh"
INTERVAL="${TL_WATCH_INTERVAL:-2}"
QUEUE="$TL_STATE/.wake-queue"
SEQ=0

# TICKS: 0 = run forever; N = N passes then exit (for tests). `--once` == 1.
TICKS="${1:-0}"; [ "${1:-}" = "--once" ] && TICKS=1

active_ids() {  # tasks with a meta whose lifecycle state is not yet torn down
  for f in "$TL_STATE"/*.meta; do
    [ -e "$f" ] || continue
    id="$(basename "$f" .meta)"
    [ "$(tl_meta_get "$id" state 2>/dev/null || echo '')" = "done" ] && continue
    echo "$id"
  done
}

enqueue() {  # id verb  — DURABLE, written before surfacing (§3.3)
  SEQ=$((SEQ + 1))
  printf '%s\t%s\t%s\t%s\n' "$(tl_now)" "$SEQ" "$2" "$1" >> "$QUEUE"
}

handle() {  # id
  local id="$1" verb action waked donec n
  verb="$("$BIN/tl-state.sh" "$id")"
  action="$(tl_action "$verb")"
  waked="$TL_STATE/$id.waked"; donec="$TL_STATE/$id.donec"
  case "$action" in
    absorb|absorb-slow)
      rm -f "$waked" "$donec" ;;                                  # positive working -> clear dedupe (§3.6)
    fallback)
      : ;;                                                        # ambiguous -> keep polling, take no fast action
    defer)                                                        # done blips; require it stable before surfacing
      n=$(( $(cat "$donec" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$donec"
      if [ "$n" -ge "${TL_DONE_STABLE:-2}" ] && [ ! -f "$waked" ]; then
        enqueue "$id" ready; touch "$waked"; tl_log "WAKE $id: ready for review"
      fi ;;
    actionable)
      if [ ! -f "$waked" ]; then
        enqueue "$id" "$verb"; touch "$waked"                     # queue first (durable), then surface
        case "$verb" in
          needs-decision|blocked) "$BIN/tl-escalate.sh" "$id" || tl_log "WAKE $id: $verb (no ask)";;
          *) tl_log "WAKE $id: $verb";;
        esac
      fi ;;
  esac
}

tick=0
while :; do
  for id in $(active_ids); do handle "$id"; done
  tick=$((tick + 1))
  [ "$TICKS" -ne 0 ] && [ "$tick" -ge "$TICKS" ] && break
  sleep "$INTERVAL"
done
