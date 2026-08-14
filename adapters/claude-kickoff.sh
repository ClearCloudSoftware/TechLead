#!/usr/bin/env bash
# claude-kickoff.sh — one turn of the kickoff interview (#60), backed by Claude headless & STREAMED.
# Reads the running transcript on stdin, calls `claude -p` with --output-format stream-json so each
# token appears in the terminal as it generates (no silent black box), and prints the lead's next turn
# on STDOUT for the loop to parse: a single question, or the final <CONTEXT>…</CONTEXT> + <BACKLOG>…
# </BACKLOG> blocks. Wire with: export TL_KICKOFF_CMD="$TL_HOME/adapters/claude-kickoff.sh"
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

raw="$(mktemp)"
# Stream each assistant text delta to the terminal (stderr) live; tee the full run to a file, then
# assemble the complete turn text on stdout for the loop. jq failures degrade to the file-based assembly.
claude -p "$prompt" --output-format stream-json --verbose </dev/null 2>/dev/null \
  | tee "$raw" \
  | jq -j --unbuffered 'select(.type=="assistant")|.message.content[]?|select(.type=="text")|.text' 2>/dev/null >&2 || true
echo >&2
# cost (best effort): the final result message carries usage/cost
jq -rs 'map(select(.type=="result"))[0] // empty' "$raw" 2>/dev/null | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_KICKOFF_ID:-kickoff}" kickoff 2>/dev/null || true
# the turn text = all assistant text concatenated
jq -rs '[.[]|select(.type=="assistant")|.message.content[]?|select(.type=="text")|.text]|join("")' "$raw" 2>/dev/null || true
rm -f "$raw"
