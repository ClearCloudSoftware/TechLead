#!/usr/bin/env bash
# harness-visibility-smoke.sh — a worker's worktree branches from HEAD, so an UNCOMMITTED test harness
# is invisible to it and to the gate (which reruns test_command there). tl-baseline and tl-spawn must
# warn when the project tree is dirty, and stay quiet when it's clean. Token-free (demo-worker).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_WORKER_CMD="$REPO/test/demo-worker.sh"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT
mkdir -p "$TL_DATA/projects"

# a registered project with a test harness that is NOT yet committed
PROJ="$(mktemp -d)"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf '#!/bin/sh\necho known-fail\n' > "$PROJ/test.sh"      # created, uncommitted
"$BIN/tl-project.sh" set app path "$PROJ"
"$BIN/tl-project.sh" set app test_command "sh test.sh"
"$BIN/tl-project.sh" set app readiness survey

echo "== H1: tl-baseline warns while the harness is uncommitted =="
"$BIN/tl-baseline.sh" app 2>"$WORK/bl1.err" >/dev/null || fail "H1: baseline errored"
grep -q "uncommitted changes" "$WORK/bl1.err" || fail "H1: no dirty-tree warning: $(cat "$WORK/bl1.err")"
grep -q "test.sh" "$WORK/bl1.err" || fail "H1: warning did not list the uncommitted harness"
echo "  H1 ok — baseline warned that the harness is uncommitted"

echo "== H2: commit the harness → tl-baseline is quiet =="
git -C "$PROJ" add -A && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m "add test harness"
"$BIN/tl-baseline.sh" app 2>"$WORK/bl2.err" >/dev/null || fail "H2: baseline errored"
grep -q "uncommitted changes" "$WORK/bl2.err" && fail "H2: warned on a clean tree (false positive): $(cat "$WORK/bl2.err")" || true
echo "  H2 ok — clean tree, no warning"

echo "== H3: tl-spawn warns when the project has uncommitted work the worker won't see =="
printf 'scratch\n' > "$PROJ/wip.txt"    # dirty again
mkdir -p "$TL_DATA/tl-h3"; echo brief > "$TL_DATA/tl-h3/brief.md"
"$BIN/tl-spawn.sh" tl-h3 --kind plan 2>"$WORK/sp1.err" >/dev/null || fail "H3: spawn errored: $(cat "$WORK/sp1.err")"
grep -q "uncommitted changes" "$WORK/sp1.err" || fail "H3: spawn did not warn on a dirty project: $(cat "$WORK/sp1.err")"
grep -q "will not see them" "$WORK/sp1.err" || fail "H3: spawn warning missing the worker-blind advice"
echo "  H3 ok — spawn warned before dispatching into a HEAD-based worktree"

echo "== H4: clean project → tl-spawn is quiet =="
git -C "$PROJ" add -A && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m wip
mkdir -p "$TL_DATA/tl-h4"; echo brief > "$TL_DATA/tl-h4/brief.md"
"$BIN/tl-spawn.sh" tl-h4 --kind plan 2>"$WORK/sp2.err" >/dev/null || fail "H4: spawn errored"
grep -q "uncommitted changes" "$WORK/sp2.err" && fail "H4: spawn warned on a clean tree (false positive)" || true
echo "  H4 ok — clean project, no warning"

echo "PASS: harness-visibility warnings fire on a dirty project (baseline + spawn) and stay quiet when clean"
