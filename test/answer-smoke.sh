#!/usr/bin/env bash
# answer-smoke.sh — Epic 9 (#59). The inward answer kind: cites its source, says "I don't know" when the
# record has no basis, flags a superseded ADR rather than quoting it as live, and is a plain query that
# spawns no worktree. Owner-only.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$WORK/inst" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_ANSWER_CMD="$REPO/test/demo-answer.sh"
mkdir -p "$TL_HOME/lead/decisions"; : > "$TL_HOME/AGENTS.md"
trap 'rm -rf "$WORK"' EXIT

cat > "$TL_HOME/lead/decisions/ADR-rotation.md" <<'EOF'
# ADR: credential rotation
Status: accepted
We rotate credentials in the order staging -> prod-eu -> prod-us.
EOF
cat > "$TL_HOME/lead/decisions/ADR-widgetstore.md" <<'EOF'
# ADR: widgetstore backend
Status: superseded
We briefly used a widgetstore backend; it was later replaced.
EOF

# a per-project grill spec under TL_DATA (which here is NOT under TL_HOME) — the corpus glob must read
# <project>/.techlead/data/*/spec.md, not $TL_HOME/data. With the old glob this spec is invisible.
mkdir -p "$TL_DATA/tl-caching"
cat > "$TL_DATA/tl-caching/spec.md" <<'EOF'
# spec: caching
We decided to use memcached for the session cache.
EOF

echo "== cites its source for an answerable question =="
a="$("$BIN/tl-answer.sh" "what did we decide about rotation order")"
printf '%s' "$a" | grep -q 'ADR-rotation'          || fail "answer did not cite the source"
printf '%s' "$a" | grep -qi 'staging'              || fail "answer did not quote the decision"

echo "== 'I don't know' when the record has no basis =="
"$BIN/tl-answer.sh" "what is our kubernetes autoscaling policy" | grep -qi "don't know" \
  || fail "did not say 'I don't know' for an unrecorded topic"

echo "== flags a superseded ADR instead of quoting it as live =="
"$BIN/tl-answer.sh" "tell me about the widgetstore backend" | grep -qi 'supersed' \
  || fail "did not flag the superseded decision"

echo "== reads a per-project grill spec (under TL_DATA), not just lead/ =="
"$BIN/tl-answer.sh" "what did we decide about memcached" | grep -qi 'memcached' \
  || fail "did not read the per-project spec corpus — tl-answer must glob \$TL_DATA/*/spec.md, not \$TL_HOME/data"

echo "== plain query: no worktree, no branch, no teardown (q2) =="
[ -z "$(ls -A "$TL_WORKTREES" 2>/dev/null || true)" ] || fail "inward answer spawned a worktree"

echo "PASS: inward answer cites or says 'I don't know', flags superseded, spawns no worktree"
