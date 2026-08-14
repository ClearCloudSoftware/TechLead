#!/usr/bin/env bash
# gate-missing-harness-smoke.sh — the change gate must FAIL CLOSED when the test harness can't run in
# the worktree (missing/broken test_command). Previously `eval … | sort` masked the command's exit
# status, so a missing harness read as "0 failures" and merged anything (fail OPEN). Token-free.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
unset TL_SPECDIFF_CMD TL_APPROVE TL_RESOLVE 2>/dev/null || true
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT
mkdir -p "$TL_DATA/projects"

# a project registered with a test harness, and a worktree that has a change but is MISSING test.sh
PROJ="$(mktemp -d)"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
BASE="$(git -C "$PROJ" rev-parse HEAD)"
echo "feature" > "$PROJ/feat.txt"          # the worker's change (no test.sh committed)
git -C "$PROJ" -c user.email=t@t -c user.name=t add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m "change"
: > "$TL_DATA/projects/app.baseline"
"$BIN/tl-project.sh" set app path "$PROJ"
"$BIN/tl-project.sh" set app test_command "sh test.sh"
"$BIN/tl-project.sh" set app baseline "$TL_DATA/projects/app.baseline"
"$BIN/tl-project.sh" set app max_files_changed 25

mkmeta() { # id worktree
  mkdir -p "$TL_STATE"
  { printf 'kind=change\nworktree=%s\nbase=%s\npname=app\nproject=%s\n' "$2" "$BASE" "$PROJ"; } > "$TL_STATE/$1.meta"
}

echo "== G1: missing harness in the worktree → gate BLOCKS with a test-harness-unrunnable finding =="
mkmeta tl-g1 "$PROJ"
if "$BIN/tl-gate.sh" tl-g1 >/tmp/gm-g1.log 2>&1; then fail "G1: gate PASSED with a missing harness (fail-open regression): $(cat /tmp/gm-g1.log)"; fi
grep -q "test-harness-unrunnable" "$TL_DATA/tl-g1/findings.json" || fail "G1: no test-harness-unrunnable finding: $(cat "$TL_DATA/tl-g1/findings.json")"
[ "$(jq -r '.[0].class' "$TL_DATA/tl-g1/findings.json")" = ask-user ] || fail "G1: finding not classified ask-user (must block)"
grep -q "gate passed" /tmp/gm-g1.log && fail "G1: gate reported passed despite the missing harness" || true
echo "  G1 ok — unrunnable harness fails closed, blocks the merge"

echo "== G2: present, passing harness → no false positive, gate passes =="
git -C "$PROJ" checkout -q -b tl-g2wt   # a branch so the worktree HEAD carries a committed test.sh
printf '#!/bin/sh\nexit 0\n' > "$PROJ/test.sh"    # runs clean, prints nothing, exit 0
git -C "$PROJ" -c user.email=t@t -c user.name=t add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m "add harness"
mkmeta tl-g2 "$PROJ"
"$BIN/tl-gate.sh" tl-g2 >/tmp/gm-g2.log 2>&1 || fail "G2: gate blocked a clean change: $(cat /tmp/gm-g2.log)"
grep -q "test-harness-unrunnable" "$TL_DATA/tl-g2/findings.json" && fail "G2: false-positive unrunnable finding on a working harness" || true
grep -q "gate passed" /tmp/gm-g2.log || fail "G2: clean change did not pass"
echo "  G2 ok — a working harness produces no unrunnable finding; gate passes"

echo "PASS: the gate fails closed on an unrunnable harness and does not false-positive on a working one"
