#!/usr/bin/env bash
# tl-escalation-loop.sh — the escalation->proposal loop (§2.6, E7.5 / #52). Any question a worker had to
# ask mid-flight is a question the grill should have asked at spec time (§2.6). Each resolved escalation
# (data/<id>/escalation.log + its ask file) becomes a candidate lead/questions.md entry, queued in
# data/proposals/ for the owner to promote.
#
# DORMANT until a worker actually produces escalations: the headless worker adapter does not yet emit
# needs-decision / write an ask file (that producer is a separate task). This loop is built and tested so
# it is ready the moment escalations start flowing.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
TAB="$(printf '\t')"

found=0
for logf in "$TL_DATA"/*/escalation.log; do
  [ -f "$logf" ] || continue
  d="$(dirname "$logf")"; id="$(basename "$d")"
  question="$(awk -F= '/^question=/{sub(/^question=/,"");print;exit}' "$d/ask" 2>/dev/null || true)"
  [ -n "$question" ] || continue
  i=0
  while IFS="$TAB" read -r ts verb ans; do
    [ "$verb" = resolved ] || continue
    i=$((i+1)); found=1
    casef="$(mktemp)"
    { printf 'task: %s\nworker asked mid-flight: %s\nresolved as: %s\n' "$id" "$question" "$ans"
      printf 'scar: the grill should have asked this at spec time so the same interruption happens once (§2.6)\n'
    } > "$casef"
    "$BIN/tl-propose.sh" question "${id}-${i}" "$casef" || true
    rm -f "$casef"
  done < "$logf"
done
[ "$found" = 1 ] || echo "tl: no worker escalations to promote yet — loop is ready; the worker-escalation producer is a separate task"
