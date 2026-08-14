#!/usr/bin/env bash
# claude-kickoff.sh — one turn of the kickoff interview (#60), backed by Claude headless. Reads the
# running transcript on stdin and prints the lead's next turn on STDOUT for the loop to parse: a single
# question, or — when it has enough — the final <CONTEXT>…</CONTEXT> + <BACKLOG>…</BACKLOG> blocks.
#
# Display: when TL_KICKOFF_STREAM=1 (set by the loop on a tty), the turn text streams token-by-token to
# STDERR as it generates (--output-format stream-json), so the interview doesn't sit silent for 5–15s
# (#114); STDOUT still carries the full assembled turn for the loop. Otherwise — or if the stream yields
# nothing — it uses the proven single-shot --output-format json path (same as claude-grill). STDOUT is
# the parse channel in both; the live stream is a preview the loop must NOT re-echo.
# Wire with: export TL_KICKOFF_CMD="$TL_HOME/adapters/claude-kickoff.sh"
set -eu
transcript="$(cat)"
prompt="You are a senior tech lead running a KICKOFF interview to bootstrap a brand-new project. Goal:
learn enough to write its CONTEXT.md (a domain glossary — the project-specific nouns/jargon, each one
line) plus 3-6 seed backlog behaviours. Ask the SINGLE most useful next question — one at a time,
plain, no preamble, no lists. Ask 2-4 questions to actually understand it — the domain's nouns, the
core behaviours, how/where things are stored, and any hard constraint — before you decide you have
enough. Don't wrap up on the first answer unless it genuinely covers all of that. When you have enough,
STOP asking and output EXACTLY these two blocks and nothing else:
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

result=""
if [ "${TL_KICKOFF_STREAM:-0}" = 1 ]; then
  # Live: stream text deltas to stderr, tee the whole stream, then lift the final result envelope.
  raw="$(mktemp)"; trap 'rm -f "$raw"' EXIT
  claude -p "$prompt" --output-format stream-json --include-partial-messages --verbose \
         --permission-mode default --max-turns 6 </dev/null \
    | tee "$raw" \
    | jq -j --unbuffered 'select(.type=="stream_event" and .event.type=="content_block_delta"
                                 and .event.delta.type=="text_delta") | .event.delta.text' >&2 || true
  # The stream-json result event is the same envelope --output-format json emits (result/usage/cost).
  result="$(jq -sr 'map(select(.type=="result"))[-1] // empty' "$raw" 2>/dev/null || true)"
fi

# Fallback (streaming off, or it produced nothing): the proven single-shot path.
[ -n "$result" ] || result="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"

printf '%s' "$result" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_KICKOFF_ID:-kickoff}" kickoff 2>/dev/null || true
printf '%s' "$result" | jq -r '.result'
