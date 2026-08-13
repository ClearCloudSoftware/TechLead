#!/usr/bin/env bash
# claude-specdiff.sh — the real Spec-axis judge (§6.4, E8.2/#54), backed by Claude Code headless.
# Wire with: export TL_SPECDIFF_CMD="$TL_HOME/adapters/claude-specdiff.sh"
#
# Contract (same as the demo): read decided questions (qid<TAB>text) on stdin, read the change diff from
# the file at TL_SD_DIFF, and emit ONE tab-separated line per question:
#   qid<TAB>verdict<TAB>why      verdict ∈ satisfied|violated|cant-eval
# The judge is *prompted, not trained* (q6): its only inputs are the decided answers and the diff.
set -eu
questions="$(cat)"
diff="$(cat "${TL_SD_DIFF:?}" 2>/dev/null || true)"

prompt="You are the Spec review axis. Below are the DECIDED answers from a feature's spec, and the diff
of the change that was built. For EACH decided question, judge whether the change honours that decided
answer. Call exactly one verdict per question:
- satisfied  — the change is consistent with the decided answer
- violated   — the change contradicts the decided answer (a non-goal implemented is a violation)
- cant-eval  — the diff does not contain enough to tell (this is NOT a pass — say so)

Decided answers (qid<TAB>text), one per line:
$questions

The change diff:
$diff

Output ONLY one tab-separated line per question and nothing else:
qid<TAB>verdict<TAB>one-line why (name the exact diff behaviour you judged)
verdict ∈ satisfied|violated|cant-eval."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 4 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_SD_ID:-(specdiff)}" spec-review || true
printf '%s' "$out" | jq -r '.result' | awk -F'\t' 'NF>=3'
