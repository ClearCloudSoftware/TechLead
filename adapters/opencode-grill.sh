#!/usr/bin/env bash
# opencode-grill.sh — grill inference driver backed by opencode (parallel to claude-grill.sh, §2.6).
# Emits one line per question: qid<TAB>answer_state<TAB>source<TAB>text. It runs opencode in a
# THROWAWAY --dir so the (tool-using) agent can't touch the instance — all the context it needs is
# in the prompt. Asks for pipe-delimited output (models emit that more reliably than literal tabs)
# and normalises to TSV, tolerating markdown-table framing.
# Wire: export TL_GRILL_CMD="$TL_HOME/adapters/opencode-grill.sh"; TL_OPENCODE_MODEL=<tools-capable>
set -eu
model="${TL_OPENCODE_MODEL:-ollama/qwen3-coder:30b}"
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

Answer every question you can from the bank + decisions (mark those source=inferred); mark the rest
source=owner. Output ONLY one line per question and NOTHING else, pipe-delimited:
answer_state | source | the question text
answer_state is one of: decided leaning open spike.  source is one of: inferred owner."

scratch="$(mktemp -d)"
out="$(opencode run "$prompt" --model "$model" --dir "$scratch" </dev/null 2>/dev/null || true)"
rm -rf "$scratch"

# normalise: strip ANSI + table pipes, then locate the answer_state field on each line (robust to
# the model reordering fields, adding a header, or narrating) and assign our own stable qids.
printf '%s\n' "$out" \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | sed 's/^[[:space:]]*|//; s/|[[:space:]]*$//' \
  | awk -F'|' '
      {
        for (i=1;i<=NF;i++){ f[i]=$i; gsub(/^[ \t]+|[ \t]+$/,"",f[i]) }
        si=0; for (i=1;i<=NF;i++) if (f[i] ~ /^(decided|leaning|open|spike)$/){ si=i; break }
        if (si==0) next                                   # no valid state -> header/narration, skip
        src="inferred"; srci=0
        if      (si+1<=NF && f[si+1] ~ /^(inferred|owner)$/){ src=f[si+1]; srci=si+1 }
        else if (si-1>=1  && f[si-1] ~ /^(inferred|owner)$/){ src=f[si-1]; srci=si-1 }
        ti=0; for (i=1;i<=NF;i++){ if (i==si||i==srci) continue; if (length(f[i])>=3){ ti=i; break } }
        if (ti==0) next
        n++; printf "q%d\t%s\t%s\t%s\n", n, f[si], src, f[ti]
      }'
