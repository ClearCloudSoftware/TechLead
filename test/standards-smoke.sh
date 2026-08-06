#!/usr/bin/env bash
# standards-smoke.sh — Epic 8 (#53). The Standards axis produces structured findings under two rule-ids
# (standards-violation / standards-smell), renders a human draft, and is DRAFT-ONLY: it must never be
# wired into the change gate (q2/q5).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_STANDARDS_CMD="$REPO/test/demo-standards.sh"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

id=tl-st-demo
# a project with a documented standards doc (AGENTS.md)
PROJ="$WORK/proj"; mkdir -p "$PROJ"; printf '# conventions\nName things clearly.\n' > "$PROJ/AGENTS.md"
git -C "$PROJ" init -q -b main; git -C "$PROJ" add -A; git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init
"$BIN/tl-project.sh" set stproj path "$PROJ"
# a worktree with a base..HEAD diff
WT="$WORK/wt"; mkdir -p "$WT"; git -C "$WT" init -q -b main
echo base > "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
echo changed >> "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change; tl_meta_set "$id" pname stproj

echo "== run: structured findings, both rule-ids, draft-only summary =="
"$BIN/tl-standards.sh" run "$id" 2>/tmp/st.rep
grep -q 'documented-violation' /tmp/st.rep || fail "run: summary missing"
grep -q 'non-blocking'          /tmp/st.rep || fail "run: not marked draft/non-blocking"
"$BIN/tl-standards.sh" findings "$id" | grep -q '^standards-violation' || fail "no standards-violation finding"
"$BIN/tl-standards.sh" findings "$id" | grep -q '^standards-smell'     || fail "no standards-smell finding"

echo "== report renders a human draft the owner disposes =="
"$BIN/tl-standards.sh" report "$id" | grep -q 'VIOLATION' || fail "report did not render the violation"

echo "== DRAFT-ONLY: Standards must never be wired into the change gate (q2/q5) =="
grep -q 'tl-standards' "$BIN/tl-gate.sh" && fail "standards axis leaked into tl-gate (must be draft-only)" || true

echo "PASS: standards axis emits two rule-ids, renders a draft, and stays out of the blocking gate"
