#!/usr/bin/env bash
# claude-grill.sh — real inference driver (§2.6). Hands the backlog item + the question bank
# (lead/questions.md) + prior decisions/ to Claude Code headless and asks it to select the relevant
# questions, answer what it can from lead/ + decisions/ (source=inferred), and mark the rest open
# (source=owner). Emits one TSV line per question: qid<TAB>answer_state<TAB>source<TAB>text[<TAB>bank#].
# The optional 5th field is the number of the bank question the answer came from (hits: signal, §2.6).
# Wire with: export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"
set -eu
body="$(cat "$TL_GRILL_BODY" 2>/dev/null || true)"
# number the bank questions so an answer can point back to the one it used (drives the hits: counter)
bank="$(awk '/^### /{n++; sub(/^### /,""); print "["n"] "$0}' "$TL_QUESTIONS" 2>/dev/null)"
[ -n "$bank" ] || bank='(empty question bank)'
decisions="$(cat "$TL_DECISIONS"/*.md 2>/dev/null || echo '(no prior decisions)')"

prompt="Run a spec grill's INFERENCE PASS for backlog item '$TL_GRILL_SLUG': $TL_GRILL_TITLE.

Item:
$body

Numbered question bank (lead/questions.md) — pick the ones that apply:
$bank

Prior decisions (lead/decisions):
$decisions

Answer every question you can from the bank + decisions; mark those source=inferred. Mark the rest
source=owner. Output ONLY one tab-separated line per question and nothing else:
qid<TAB>answer_state<TAB>source<TAB>text<TAB>bank#
answer_state ∈ decided|leaning|open|spike, source ∈ inferred|owner. bank# is the [N] of the bank
question this answer came from, or empty for a question not drawn from the bank."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_GRILL_ID:-(grill)}" grill || true
printf '%s' "$out" | jq -r '.result' | awk -F'\t' 'NF>=4'
