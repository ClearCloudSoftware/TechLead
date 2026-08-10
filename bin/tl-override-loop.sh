#!/usr/bin/env bash
# tl-override-loop.sh — the override->proposal loop (§2.5, E7.4 / #51). When the owner overrules the lead
# by correcting an inferred grill answer (logged to data/inferred-outcomes.tsv), that correction becomes
# a candidate lead/principles.md rule — the rule that would have made the lead agree. Draft-only: the
# candidate lands in data/proposals/ for the owner to promote; nothing is ever written into lead/.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
TAB="$(printf '\t')"
log="$TL_DATA/inferred-outcomes.tsv"
[ -f "$log" ] || { echo "tl: no corrections yet ($log)"; exit 0; }

while IFS="$TAB" read -r date task qid verdict delta; do
  [ "$verdict" = correct ] || continue
  answer="$("$BIN/tl-spec.sh" qlist "$task" 2>/dev/null | awk -F'|' -v q="$qid" '$1==q{print $5}' || true)"
  casef="$(mktemp)"
  { printf 'task: %s\nquestion-id: %s\ndate: %s\noverride: %s\n' "$task" "$qid" "$date" "$delta"
    printf 'lead inferred: %s ; owner corrected to: %s\n' "${delta%%->*}" "${delta##*->}"
    printf "owner's corrected answer: %s\n" "${answer:-(answer text not found)}"
  } > "$casef"
  "$BIN/tl-propose.sh" rule "${task}-${qid}" "$casef" || true
  rm -f "$casef"
done < "$log"
echo "tl: override loop swept ${log#"$TL_DATA"/}"
