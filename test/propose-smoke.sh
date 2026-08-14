#!/usr/bin/env bash
# propose-smoke.sh — grill propose-mode (#49 bootstrap): an empty bank drafts candidate questions the
# owner prunes + promotes into lead/questions.md, then the ordinary grill runs. Token-free
# (demo-grill-propose), deterministic. Proves: propose drafts to data/proposals/ (never lead/); promote
# appends only survivors as provisional entries and archives; an all-pruned file is a no-op; and tl-run
# auto-fires propose at the empty-bank guard instead of dispatching un-grilled work.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_LEAD="$WORK/lead" TL_WORKTREES="$WORK/state/wt"
export TL_BACKLOG="$WORK/data/backlog.md"
export TL_GRILL_PROPOSE_CMD="$REPO/test/demo-grill-propose.sh"
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT
mkdir -p "$TL_DATA" "$TL_LEAD"
: > "$TL_LEAD/questions.md"   # empty bank
cat > "$TL_BACKLOG" <<'EOF'
# Backlog

## greet: print a greeting
Add hello() to greet.sh.

## empty: an item whose candidates all get pruned
EOF

echo "== P1: tl-grill propose drafts candidates into data/proposals/ (never lead/) =="
"$BIN/tl-grill.sh" propose greet >/tmp/ps-p1.log 2>&1 || fail "P1: propose errored: $(cat /tmp/ps-p1.log)"
PROP="$TL_DATA/proposals/question-greet.md"
[ -f "$PROP" ] || fail "P1: no proposal drafted at $PROP"
[ "$(grep -c '^### ' "$PROP")" -eq 3 ] || fail "P1: expected 3 candidate '### ' lines, got $(grep -c '^### ' "$PROP")"
grep -q "backlog item 'greet'" "$PROP" || fail "P1: proposal not labelled from the backlog item"
[ ! -s "$TL_LEAD/questions.md" ] || fail "P1: propose wrote into lead/ (must be owner-only)"
echo "  P1 ok — 3 candidates in the proposal, lead/questions.md untouched"

echo "== P2: prune to 2, promote → only survivors land as provisional entries; proposal archived =="
grep -v '### What are the edge cases' "$PROP" > "$PROP.tmp" && mv "$PROP.tmp" "$PROP"   # owner cuts one
"$BIN/tl-grill.sh" promote greet >/tmp/ps-p2.log 2>&1 || fail "P2: promote errored: $(cat /tmp/ps-p2.log)"
[ "$(grep -c '^### ' "$TL_LEAD/questions.md")" -eq 2 ] || fail "P2: expected 2 promoted questions, got $(grep -c '^### ' "$TL_LEAD/questions.md")"
grep -q '_scar:_ (proposed — unproven)' "$TL_LEAD/questions.md" || fail "P2: promoted entries not marked provisional"
[ "$(grep -c 'hits: 0' "$TL_LEAD/questions.md")" -eq 2 ] || fail "P2: promoted entries missing hits:0"
grep -q 'edge cases' "$TL_LEAD/questions.md" && fail "P2: the pruned candidate leaked into the bank" || true
[ -f "$PROP.promoted" ] && [ ! -f "$PROP" ] || fail "P2: proposal not archived to .promoted"
echo "  P2 ok — 2 provisional questions promoted, pruned one dropped, proposal archived"

echo "== P3: an all-pruned proposal is a no-op (nothing promoted) =="
"$BIN/tl-grill.sh" propose empty >/dev/null 2>&1 || fail "P3: propose empty errored"
EPROP="$TL_DATA/proposals/question-empty.md"
grep -v '^### ' "$EPROP" > "$EPROP.tmp" && mv "$EPROP.tmp" "$EPROP"   # owner cuts everything
before="$(grep -c '^### ' "$TL_LEAD/questions.md")"
"$BIN/tl-grill.sh" promote empty >/tmp/ps-p3.log 2>&1 || fail "P3: promote errored"
grep -q "nothing to promote" /tmp/ps-p3.log || fail "P3: all-pruned promote was not a no-op: $(cat /tmp/ps-p3.log)"
[ "$(grep -c '^### ' "$TL_LEAD/questions.md")" -eq "$before" ] || fail "P3: bank changed on an empty promote"
[ ! -f "$EPROP.promoted" ] || fail "P3: archived a proposal that promoted nothing"
echo "  P3 ok — empty promote changed nothing, did not archive"

echo "== P4: tl-run auto-fires propose at the empty-bank guard instead of dispatching =="
: > "$TL_LEAD/questions.md"   # reset bank to empty
rm -f "$TL_DATA/proposals/question-greet.md.promoted" "$TL_DATA"/tl-greet/spec.md 2>/dev/null || true
rm -rf "$TL_DATA/tl-greet"
TL_GRILL_CMD=/usr/bin/true "$BIN/tl-run.sh" greet >/tmp/ps-p4.log 2>&1 || true
grep -q "drafted candidates" /tmp/ps-p4.log || fail "P4: tl-run did not auto-fire propose: $(cat /tmp/ps-p4.log)"
[ -f "$TL_DATA/proposals/question-greet.md" ] || fail "P4: tl-run did not draft the proposal"
[ ! -f "$TL_STATE/tl-greet.meta" ] || fail "P4: dispatched un-grilled work despite empty bank"
echo "  P4 ok — auto-drafted candidates and refused to dispatch"

echo "PASS: propose drafts (not lead/), promote lands survivors provisionally + archives, empty promote is a no-op, tl-run auto-proposes at the guard"
