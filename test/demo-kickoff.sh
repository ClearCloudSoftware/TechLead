#!/usr/bin/env bash
# demo-kickoff.sh — deterministic kickoff driver for tests. Reads the transcript on stdin; asks a
# question until it has seen 2 owner answers, then emits the final CONTEXT + BACKLOG blocks. No model.
set -eu
transcript="$(cat)"
n="$(printf '%s\n' "$transcript" | grep -c '^OWNER:' || true)"
if [ "$n" -lt 2 ]; then
  printf 'What is the core domain noun and what does it do?\n'
else
  cat <<'EOF'
<CONTEXT>
# CONTEXT.md

## Glossary
- **widget** — the core domain noun; the thing this app manages.
</CONTEXT>
<BACKLOG>
add-widget|Add a widget|create a widget from input text
list-widgets|List widgets|print all widgets, newest first
</BACKLOG>
EOF
fi
