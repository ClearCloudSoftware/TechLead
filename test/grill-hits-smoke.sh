#!/usr/bin/env bash
# grill-hits-smoke.sh — a bank question that justified an inferred answer during a grill has "fired":
# its hits: counter bumps and last: is stamped (§2.6, SHAPE.md; the D4 reuse signal). The grill driver
# reports which bank question each answer used via the optional 5th TSV field. Token-free.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$WORK/inst" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_LEAD="$WORK/inst/lead"
export TL_WORKTREES="$WORK/state/wt" TL_BACKLOG="$WORK/data/backlog.md"
export TL_GRILL_CMD="$REPO/test/demo-grill-hits.sh"
mkdir -p "$TL_HOME/lead" "$TL_DATA"; : > "$TL_HOME/AGENTS.md"
trap 'rm -rf "$WORK"' EXIT
today="$(date -u +%Y-%m-%d)"

cat > "$TL_LEAD/questions.md" <<'EOF'
# questions

### Does the item include creating the file?
hits: 0   last: —
_scar:_ (proposed — unproven)

### Is the output a literal string?
hits: 3   last: 2026-01-01
_scar:_ real scar
EOF
cat > "$TL_BACKLOG" <<'EOF'
# Backlog

## greet: print a greeting
Add hello() to greet.sh.
EOF

# hits of the Nth `### ` entry, as "hits: N   last: X"
hline() { awk -v k="$1" '/^### /{n++} n==k && /^hits:/{print; exit}' "$TL_LEAD/questions.md"; }

echo "== H1: a grill bumps the bank questions it drew answers from, stamps last =="
"$BIN/tl-grill.sh" greet >/tmp/gh-h1.log 2>&1 || fail "H1: grill errored: $(cat /tmp/gh-h1.log)"
printf '%s' "$(hline 1)" | grep -q 'hits: 1' || fail "H1: entry 1 not bumped 0->1 (got: $(hline 1))"
printf '%s' "$(hline 1)" | grep -q "last: $today" || fail "H1: entry 1 last not stamped (got: $(hline 1))"
printf '%s' "$(hline 2)" | grep -q 'hits: 4' || fail "H1: entry 2 not bumped 3->4 (got: $(hline 2))"
printf '%s' "$(hline 2)" | grep -q "last: $today" || fail "H1: entry 2 last not restamped (got: $(hline 2))"
echo "  H1 ok — entries 1 and 2 bumped and dated"

echo "== H2: the owner delta (no bank ref) added no phantom bank entry =="
[ "$(grep -c '^### ' "$TL_LEAD/questions.md")" -eq 2 ] || fail "H2: bank size changed (grill must bump, not append)"
echo "  H2 ok — bank still 2 entries"

echo "== H3: re-grilling accumulates (a fired question keeps earning) =="
rm -rf "$TL_DATA/tl-greet"   # fresh grill of the same item
"$BIN/tl-grill.sh" greet >/tmp/gh-h3.log 2>&1 || fail "H3: re-grill errored"
printf '%s' "$(hline 1)" | grep -q 'hits: 2' || fail "H3: entry 1 did not accumulate 1->2 (got: $(hline 1))"
printf '%s' "$(hline 2)" | grep -q 'hits: 5' || fail "H3: entry 2 did not accumulate 4->5 (got: $(hline 2))"
echo "  H3 ok — hits accumulate across grills"

echo "PASS: hits: auto-bumps the bank questions a grill uses, stamps last, accumulates, adds no phantom entries"
