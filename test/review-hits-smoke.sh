#!/usr/bin/env bash
# review-hits-smoke.sh — the review-side mirror of grill-hits: a review-rubric rule that justified a
# Standards finding has "fired", so its hits: bumps and last: is stamped (§2.6, SHAPE.md). The Standards
# judge reports the cited rule via the optional 4th TSV field; tl-standards bumps it and stores 3-field
# findings so downstream is unchanged. Token-free.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt" TL_LEAD="$WORK/lead"
export TL_STANDARDS_CMD="$REPO/test/demo-standards-hits.sh"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT
today="$(date -u +%Y-%m-%d)"

mkdir -p "$TL_LEAD"
cat > "$TL_LEAD/review-rubric.md" <<'EOF'
# review-rubric

### Name things clearly
hits: 0   last: —

### No duplicated blocks
hits: 5   last: 2026-01-01
EOF

id=tl-rh
PROJ="$WORK/proj"; mkdir -p "$PROJ"; printf '# conventions\nName things clearly.\n' > "$PROJ/AGENTS.md"
git -C "$PROJ" init -q -b main; git -C "$PROJ" add -A; git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init
"$BIN/tl-project.sh" set rhproj path "$PROJ"
WT="$WORK/wt"; mkdir -p "$WT"; git -C "$WT" init -q -b main
echo base > "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
echo changed >> "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change; tl_meta_set "$id" pname rhproj

hline() { awk -v k="$1" '/^### /{n++} n==k && /^hits:/{print; exit}' "$TL_LEAD/review-rubric.md"; }

echo "== R1: a review bumps the rubric rules its findings cited, stamps last =="
"$BIN/tl-standards.sh" run "$id" 2>/dev/null
printf '%s' "$(hline 1)" | grep -q 'hits: 1' || fail "R1: rubric rule 1 not bumped 0->1 (got: $(hline 1))"
printf '%s' "$(hline 1)" | grep -q "last: $today" || fail "R1: rule 1 last not stamped (got: $(hline 1))"
printf '%s' "$(hline 2)" | grep -q 'hits: 6' || fail "R1: rubric rule 2 not bumped 5->6 (got: $(hline 2))"
printf '%s' "$(hline 2)" | grep -q "last: $today" || fail "R1: rule 2 last not restamped (got: $(hline 2))"
echo "  R1 ok — cited rubric rules bumped and dated"

echo "== R2: stored findings stay 3-field (the rubric# never leaks downstream) =="
"$BIN/tl-standards.sh" findings "$id" | awk -F'\t' 'NF>3{exit 1}' || fail "R2: a 4th field leaked into stored findings"
[ "$("$BIN/tl-standards.sh" findings "$id" | grep -c .)" -eq 3 ] || fail "R2: expected 3 findings stored"
echo "  R2 ok — findings unchanged for report/compose"

echo "PASS: a review bumps the review-rubric rules it cited + stamps last; stored findings stay 3-field"
