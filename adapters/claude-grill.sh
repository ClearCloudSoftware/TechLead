#!/usr/bin/env bash
# claude-grill.sh — real inference driver (§2.6). Hands the backlog item + the question bank
# (lead/questions.md) + prior decisions/ to Claude Code headless and asks it to select the relevant
# questions, answer what it can from lead/ + decisions/ (source=inferred), and mark the rest open
# (source=owner). Emits one TSV line per question: qid<TAB>answer_state<TAB>source<TAB>text.
# Wire with: export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"
set -eu
body="$(cat "$TL_GRILL_BODY" 2>/dev/null || true)"
bank="$(cat "$TL_QUESTIONS" 2>/dev/null || echo '(empty question bank)')"
decisions="$(cat "$TL_DECISIONS"/*.md 2>/dev/null || echo '(no prior decisions)')"

prompt="Run a spec grill's INFERENCE PASS for backlog item '$TL_GRILL_SLUG': $TL_GRILL_TITLE.

Item:
$body

Question bank (lead/questions.md) — pick the ones that apply:
$bank

Prior decisions (lead/decisions):
$decisions

Answer every question you can from the bank + decisions; mark those source=inferred. Mark the rest
source=owner. Output ONLY one tab-separated line per question and nothing else:
qid<TAB>answer_state<TAB>source<TAB>text
answer_state ∈ decided|leaning|open|spike, source ∈ inferred|owner."

claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 \
  | jq -r '.result' | awk -F'\t' 'NF>=4'
