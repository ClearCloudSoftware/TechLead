#!/usr/bin/env bash
# tl-review.sh — the review kind (§2.2, D6, E8.6 / #58). Reviews an existing, built change along TWO
# axes run as PARALLEL sub-agents so neither pollutes the other (§2.2): Standards (borrowed /code-review
# craft, tl-standards) and Spec (the intent differentiator, tl-specdiff). It composes a single DRAFT the
# owner disposes — draft-only: nothing here posts, merges, or resolves (spec-diff qi5). The Spec axis
# also runs blocking at the change gate; this is its standalone draft home.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-review <change-id>}"
[ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id — review needs a grilled change"
draft="$TL_DATA/$id/review-draft.md"; mkdir -p "$TL_DATA/$id"

# run the two axes apart and in parallel (§2.2) — nits must not drown intent
"$BIN/tl-specdiff.sh"  run "$id" 2>/dev/null &  spec_pid=$!
"$BIN/tl-standards.sh" run "$id" 2>/dev/null &  std_pid=$!
wait "$spec_pid" 2>/dev/null || true
wait "$std_pid"  2>/dev/null || true

{
  printf '# Review draft — %s\n\n' "$id"
  printf '_Draft only — the owner disposes; nothing is posted, merged, or resolved here (§2.2)._\n\n'
  printf '## Spec (intent — the change vs the decided answers)\n\n'
  "$BIN/tl-specdiff.sh"  report "$id" 2>/dev/null || echo "(spec axis did not run — is TL_SPECDIFF_CMD set?)"
  printf '\n## Standards (borrowed craft — advisory)\n\n'
  "$BIN/tl-standards.sh" report "$id" 2>/dev/null || echo "(standards axis did not run — is TL_STANDARDS_CMD set?)"
} > "$draft"

echo "tl: review draft -> $draft  (draft only — nothing posted)"
cat "$draft"
