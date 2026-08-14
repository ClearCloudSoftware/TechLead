#!/usr/bin/env bash
# backlog-smoke.sh — tl-backlog add appends a well-formed, grill-matchable item (validated slug, no
# duplicate, creates the file), and list shows them. Token-free.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_BACKLOG="$WORK/data/backlog.md"
trap 'rm -rf "$WORK"' EXIT

echo "== B1: add creates the backlog and appends a well-formed heading + description =="
"$BIN/tl-backlog.sh" add add-search "Add full-text search" "Filter notes by title+body. Touches list.js." >/tmp/bl-b1.log 2>&1 \
  || fail "B1: add errored: $(cat /tmp/bl-b1.log)"
[ -f "$TL_BACKLOG" ] || fail "B1: backlog not created"
grep -qx '## add-search: Add full-text search' "$TL_BACKLOG" || fail "B1: heading not appended in the exact format"
grep -q 'Filter notes by title' "$TL_BACKLOG" || fail "B1: description not appended"
head -1 "$TL_BACKLOG" | grep -q '^# Backlog' || fail "B1: missing the # Backlog header"
echo "  B1 ok — created + appended a well-formed item"

echo "== B2: the added slug is what tl-grill matches (same heading rule) =="
title="$(awk -v s=add-search 'index($0,"## "s":")==1{t=$0; sub("^## [^:]*: *","",t); print t; exit}' "$TL_BACKLOG")"
[ "$title" = "Add full-text search" ] || fail "B2: tl-grill's heading match would not resolve the item (got: '$title')"
echo "  B2 ok — grill-matchable"

echo "== B3: a second item with no description is fine; list shows both =="
"$BIN/tl-backlog.sh" add fix-crash "Fix the crash on empty list" >/dev/null 2>&1 || fail "B3: add w/o description errored"
n="$("$BIN/tl-backlog.sh" list | grep -c .)"
[ "$n" -eq 2 ] || fail "B3: list did not show 2 items (got $n)"
"$BIN/tl-backlog.sh" list | grep -q 'add-search: Add full-text search' || fail "B3: list missing the first item"
echo "  B3 ok — description optional; list shows both"

echo "== B4: rejects a duplicate slug =="
if "$BIN/tl-backlog.sh" add add-search "Another one" >/tmp/bl-b4.log 2>&1; then fail "B4: allowed a duplicate slug"; fi
grep -q 'already has an item' /tmp/bl-b4.log || fail "B4: wrong duplicate error: $(cat /tmp/bl-b4.log)"
echo "  B4 ok — duplicate refused"

echo "== B5: rejects malformed slugs (uppercase, spaces, slashes, edge hyphens) =="
for bad in "Add-Search" "add search" "a/b" "-lead" "trail-"; do
  if "$BIN/tl-backlog.sh" add "$bad" "x" >/dev/null 2>&1; then fail "B5: accepted a bad slug: '$bad'"; fi
done
[ "$("$BIN/tl-backlog.sh" list | grep -c .)" -eq 2 ] || fail "B5: a bad slug still got written"
echo "  B5 ok — malformed slugs refused, nothing written"

echo "== B6: rejects a title containing a newline (would split the heading) =="
if "$BIN/tl-backlog.sh" add multi "$(printf 'line one\nline two')" >/tmp/bl-b6.log 2>&1; then fail "B6: accepted a multi-line title"; fi
grep -q 'single line' /tmp/bl-b6.log || fail "B6: wrong error for a multi-line title: $(cat /tmp/bl-b6.log)"
grep -q '^## multi:' "$TL_BACKLOG" && fail "B6: a broken heading was written" || true
echo "  B6 ok — multi-line title refused, nothing written"

echo "== B7: adding to a header-less backlog restores the # Backlog H1 =="
HL="$WORK/headerless.md"; printf '## existing: an item with no H1 header\nbody line\n' > "$HL"
TL_BACKLOG="$HL" "$BIN/tl-backlog.sh" add fresh "A fresh item" >/dev/null 2>&1 || fail "B7: add errored"
head -1 "$HL" | grep -q '^# Backlog' || fail "B7: did not restore the # Backlog header"
grep -qx '## existing: an item with no H1 header' "$HL" || fail "B7: clobbered the pre-existing item"
grep -qx '## fresh: A fresh item' "$HL" || fail "B7: did not append the new item"
echo "  B7 ok — header restored, existing + new items intact"

echo "PASS: tl-backlog add appends grill-matchable items with a slug guard + no duplicates; list works"
