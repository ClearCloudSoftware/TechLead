#!/usr/bin/env bash
# demo-specdiff.sh — deterministic Spec-axis judge for tests. Reads decided questions (qid<TAB>text) on
# stdin, emits qid<TAB>verdict<TAB>why. Behaviour is fixed by TL_SD_DEMO (clean|violate|uncheckable):
# the first question takes the chosen verdict, the rest are satisfied. A real judge reads TL_SD_DIFF.
set -eu
TAB="$(printf '\t')"; mode="${TL_SD_DEMO:-clean}"; first=1
while IFS="$TAB" read -r qid text; do
  [ -n "$qid" ] || continue
  if [ "$first" = 1 ] && [ "$mode" = violate ]; then
    printf '%s\tviolated\tthe change does the opposite of this decided answer\n' "$qid"
  elif [ "$first" = 1 ] && [ "$mode" = uncheckable ]; then
    printf '%s\tcant-eval\tthe diff does not touch anything this question covers\n' "$qid"
  else
    printf '%s\tsatisfied\tthe change matches the decided answer\n' "$qid"
  fi
  first=0
done
