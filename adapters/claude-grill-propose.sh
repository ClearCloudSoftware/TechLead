#!/usr/bin/env bash
# claude-grill-propose.sh — propose-mode driver (E?/#49 bootstrap). When lead/questions.md is thin or
# empty, the grill has nothing to ask; this proposes CANDIDATE questions for a backlog item so the
# owner has something to curate. It NEVER writes lead/ — tl-propose wraps this draft into a
# data/proposals/ file for the owner to prune + promote. Sees the item PLUS the existing bank +
# decisions/ (Q6) so it complements rather than duplicates, and mirrors the owner's phrasing.
#
# Contract: reads the backlog item from $TL_PROP_CASE; emits one candidate per line as an h3 heading:
#   ### <the question, phrased the way a senior would ask it>
#   _why:_ <one line so the owner can keep/cut fast>   (optional; promote ignores it)
# tl-grill promote extracts the `### ` lines; the `_why:_` is curation guidance only, not bank content.
set -eu
item="$(cat "$TL_PROP_CASE" 2>/dev/null || true)"
bank="$(cat "$TL_LEAD/questions.md" 2>/dev/null || echo '(empty — no questions yet)')"
decisions="$(cat "$TL_LEAD"/decisions/*.md 2>/dev/null || echo '(no prior decisions)')"

prompt="You are a SENIOR tech lead building a reusable question bank. For the backlog item below,
propose 4-6 CANDIDATE questions worth asking before anyone writes code — the kind whose absence
bites later (scope boundary, data/persistence, error + edge behavior, interface/signature, what
'done' means, security/permissions if relevant). Sharp and specific to THIS item, not generic PM
filler. Do NOT duplicate questions already in the bank; complement it, and match its phrasing.

Backlog item:
$item

Existing question bank (lead/questions.md) — do not repeat these:
$bank

Prior decisions (lead/decisions) — respect these, don't re-ask what they settle:
$decisions

Output ONLY the candidates, one per h3 heading, each with a one-line rationale, nothing else:
### <question>
_why:_ <one line>"

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_PROP_KEY:-(propose)}" grill-propose || true
# keep only the candidate lines (h3 questions + their why); drop any stray prose the model adds
printf '%s' "$out" | jq -r '.result' | awk '/^### /||/^_why:/'
