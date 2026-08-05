#!/usr/bin/env bash
# tl-specdiff.sh — the Spec review axis (§2.2, §6.4, E8.2 / #54). The differentiator: it diffs a
# finished change against its spec.md DECIDED questions and reports, per question, satisfied / violated
# / couldn't-evaluate — every verdict showing its work (the qid, and a one-line why from the judge).
#
# Division of labour (q2): this SCRIPT does coverage bookkeeping only (which decided qids exist, run the
# judge, tally); an LLM sub-agent (TL_SPECDIFF_CMD) makes the satisfied/violated/cant-eval call. Loudness
# is marker-driven (q1): only `decided` questions can be violated — leaning/open/spike are never
# violations. "Couldn't-evaluate" is as loud as a violation, no silent pass (q3). Findings tie to qids (qi4).
#
# Two homes (q5): the delivery gate folds `findings` into every change (a violation blocks via #55, the
# classifier), and the `review` kind renders `report` draft-only.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
TAB="$(printf '\t')"
vf_path() { printf '%s/%s/spec-verdicts.tsv' "$TL_DATA" "$1"; }

case "${1:?usage: tl-specdiff run|findings|report ID}" in
  run)  # invoke the judge over decided questions; cache verdicts; print the human report to stderr
    id="${2:?}"; wt="$(tl_meta_get "$id" worktree)"; base="$(tl_meta_get "$id" base)"
    [ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id"
    decided="$("$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '$2=="decided"{printf "%s\t%s\n",$1,$5}')"
    vf="$(vf_path "$id")"; mkdir -p "$(dirname "$vf")"; : > "$vf"
    n="$(printf '%s' "$decided" | grep -c . || true)"
    [ "$n" -eq 0 ] && { echo "tl: spec axis — no decided questions to check for $id" >&2; exit 0; }
    : "${TL_SPECDIFF_CMD:?tl: no spec-diff judge — set TL_SPECDIFF_CMD (e.g. adapters/claude-specdiff.sh)}"
    diff="$(mktemp)"; git -C "$wt" --no-pager diff "$base"..HEAD > "$diff" 2>/dev/null || true
    # judge reads decided questions (qid<TAB>text) on stdin + the diff at TL_SD_DIFF; emits one line per
    # question: qid<TAB>verdict<TAB>why  (verdict ∈ satisfied|violated|cant-eval)
    printf '%s\n' "$decided" | TL_SD_ID="$id" TL_SD_DIFF="$diff" $TL_SPECDIFF_CMD \
      | while IFS="$TAB" read -r qid verdict why; do
          [ -n "$qid" ] || continue
          case "$verdict" in satisfied|violated|cant-eval) ;; *) verdict=cant-eval; why="judge returned an unknown verdict";; esac
          printf '%s\t%s\t%s\n' "$qid" "$verdict" "$why" >> "$vf"
        done
    rm -f "$diff"
    awk -F'\t' -v tot="$n" '
      {c++; if($2=="satisfied")s++; else if($2=="violated")x++; else q++;
       m=($2=="satisfied"?"OK":($2=="violated"?"XX":"??")); lines=lines sprintf("  [%s] %s — %s\n",m,$1,$3)}
      END{printf "tl: spec axis — %d of %d decided questions checked: %d satisfied, %d violated, %d uncheckable\n%s",c,tot,s+0,x+0,q+0,lines}
    ' "$vf" >&2
    ;;
  findings)  # emit rule<TAB>detail<TAB>path for the gate — violations AND uncheckables are both loud
    id="${2:?}"; vf="$(vf_path "$id")"; [ -f "$vf" ] || exit 0
    awk -F'\t' '
      $2=="violated"  {printf "spec-violation\t%s decided answer contradicted: %s\t\n",$1,$3}
      $2=="cant-eval" {printf "spec-uncheckable\t%s could not be evaluated: %s\t\n",$1,$3}
    ' "$vf"
    ;;
  report)  # human per-question report from cached verdicts (review kind / owner draft)
    id="${2:?}"; vf="$(vf_path "$id")"; [ -f "$vf" ] || { echo "no spec verdicts for $id (run tl-specdiff run $id)"; exit 0; }
    awk -F'\t' '{m=($2=="satisfied"?"[OK]":($2=="violated"?"[XX]":"[??]")); printf "%s %s — %s\n",m,$1,$3}' "$vf"
    ;;
  *) tl_die "usage: tl-specdiff run|findings|report ID";;
esac
