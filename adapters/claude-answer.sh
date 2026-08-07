#!/usr/bin/env bash
# claude-answer.sh — the inward answer engine (§7.2, E9.1/#59), backed by Claude headless. Answers the
# owner's question STRICTLY from their written record, with a citation per claim or an honest "I don't
# know", respecting ADR Status. Owner-only, zero blast radius (qi4). Prompted, not trained.
# Wire with: export TL_ANSWER_CMD="$TL_HOME/adapters/claude-answer.sh"
#
# Contract: read the question from TL_ANS_Q and the assembled corpus from the file at TL_ANS_CORPUS;
# print the answer on stdout (to the owner only).
set -eu
corpus="$(cat "${TL_ANS_CORPUS:?}" 2>/dev/null || true)"

prompt="Answer the owner's own question STRICTLY from their written record below — their decisions
(ADRs), grill specs, and principles. Rules:
- CITE the source (the SOURCE path + the specific decision/spec line) for EVERY claim you make.
- If the record has no solid basis, answer exactly: \"I don't know — no basis in your notes.\" Never
  guess or fill gaps. Confident-wrong on the owner's own notes is the one failure to avoid.
- Respect ADR Status: if a decision is superseded or rejected, say so and flag it — never quote a
  superseded decision as if it were current. Flag the age of old decisions.
- You are answering the OWNER only, reading their notes back to them. Propose nothing, send nothing.

Question: $TL_ANS_Q

The record:
$corpus"

claude -p "$prompt" --output-format json --permission-mode default --max-turns 3 </dev/null | jq -r '.result'
