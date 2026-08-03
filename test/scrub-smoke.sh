#!/usr/bin/env bash
# scrub-smoke.sh — tl-scrub blocks secret shapes, passes clean content, scans dirs, and NEVER
# edits the file it flags (escalate-don't-drop). No network, no real LLM.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT

# clean: mentions "secrets" and "token: q3" as prose — must NOT trip the generic pattern.
clean="$WORK/clean.md"
printf '# ADR-001\nReuse the existing secrets backend; token: q3 missed the rotation case.\n' > "$clean"
# dirty: a real AWS access-key-id shape.
dirty="$WORK/dirty.md"
printf '# ADR-002\nleftover from debugging: AKIA1234567890ABCDEF\n' > "$dirty"

echo "== clean prose passes =="
"$BIN/tl-scrub.sh" "$clean" || fail "clean content was flagged"

echo "== a secret is blocked (non-zero exit) =="
if "$BIN/tl-scrub.sh" "$dirty" 2>/dev/null; then fail "secret slipped through"; fi

echo "== escalate-don't-drop: the flagged file is untouched =="
grep -q AKIA "$dirty" || fail "scrub stripped content instead of escalating"

echo "== directory scan finds the planted secret =="
if "$BIN/tl-scrub.sh" "$WORK" 2>/dev/null; then fail "dir scan missed the secret"; fi

echo "PASS: scrub-smoke"
