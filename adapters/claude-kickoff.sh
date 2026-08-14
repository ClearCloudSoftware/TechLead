#!/usr/bin/env bash
# claude-kickoff.sh — one turn of the kickoff interview (#60), backed by Claude headless. Reads the
# running transcript on stdin and prints the lead's next turn on STDOUT for the loop to parse: a single
# question, or — when it has enough — the final <CONTEXT>…</CONTEXT> + <BACKLOG>…</BACKLOG> blocks.
# Uses --output-format json (same proven path as claude-grill); the loop displays the question.
# Wire with: export TL_KICKOFF_CMD="$TL_HOME/adapters/claude-kickoff.sh"
set -eu
transcript="$(cat)"
prompt="You are a senior tech lead running a KICKOFF interview to bootstrap a brand-new project. Goal:
learn enough to write its CONTEXT.md (a domain glossary — the project-specific nouns/jargon, each one
line) plus 3-6 seed backlog behaviours. Ask the SINGLE most useful next question — one at a time,
plain, no preamble, no lists. When you have enough, STOP asking and output EXACTLY these two blocks and
nothing else:
<CONTEXT>
# CONTEXT.md

## Glossary
- **term** — one-line definition.
</CONTEXT>
<BACKLOG>
slug|Title|one-line description
</BACKLOG>
(backlog: one behaviour per line; slug is lowercase-with-hyphens.)

Conversation so far:
$transcript"

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_KICKOFF_ID:-kickoff}" kickoff 2>/dev/null || true
printf '%s' "$out" | jq -r '.result'
