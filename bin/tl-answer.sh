#!/usr/bin/env bash
# tl-answer.sh — the inward answer kind (§7.2, D7, E9.1 / #59). Answers the OWNER's own questions from
# the owner's own written record — why X, state of Y, what we decided about Z — with a CITATION per claim,
# or "I don't know / no basis in your notes" (never a manufactured guess, q1). Owner-only, zero blast
# radius (qi4): it reads notes back to the owner — no merges, no code, no other audience. A lightweight
# QUERY, not a task kind: no worktree/branch/teardown (q2).
#
# Corpus (q3, single owner of what counts as the record): lead/decisions/ (ADRs) + data/*/spec.md (grill
# specs) + lead/principles.md + a project CONTEXT.md if given. NOT briefs/backlog/state (throwaway or
# not-yet-decisions). The engine respects ADR Status — flags superseded/stale rather than quoting as live
# (q4). Plain-text corpus, no embeddings (q4).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
q="${1:?usage: tl-answer \"<question>\" [project-CONTEXT.md]}"
context_md="${2:-}"

corpus="$(mktemp)"
add() { [ -f "$1" ] || return 0; case "$1" in */TEMPLATE.md) return 0;; esac
        printf '\n===== SOURCE: %s =====\n' "${1#"$TL_HOME"/}" >> "$corpus"; cat "$1" >> "$corpus"; }
for f in "$TL_LEAD"/decisions/*.md; do add "$f"; done
for f in "$TL_DATA"/*/spec.md;          do add "$f"; done   # per-project specs (<project>/.techlead/data)
add "$TL_LEAD/principles.md"
[ -n "$context_md" ] && add "$context_md"

if [ ! -s "$corpus" ]; then rm -f "$corpus"; echo "I don't know — your written record is empty."; exit 0; fi

: "${TL_ANSWER_CMD:?tl: no answer engine — set TL_ANSWER_CMD (e.g. adapters/claude-answer.sh)}"
TL_ANS_Q="$q" TL_ANS_CORPUS="$corpus" $TL_ANSWER_CMD
rm -f "$corpus"
