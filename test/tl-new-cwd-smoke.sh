#!/usr/bin/env bash
# tl-new-cwd-smoke.sh — tl-new creates the project in the CURRENT directory by default (like git init /
# cargo new), not under TL_HOME/projects; an explicit TL_PROJECTS_DIR still overrides for a fixed home.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt" TL_CONFIG=/dev/null
unset TL_PROJECTS_DIR 2>/dev/null || true
trap 'rm -rf "$WORK"' EXIT

echo "== no fixed home: tl-new creates ./<name> in the CWD =="
HERE="$WORK/here"; mkdir -p "$HERE"
( cd "$HERE" && "$BIN/tl-new.sh" myapp --yes </dev/null >/dev/null 2>&1 )
[ -d "$HERE/myapp/.git" ]      || fail "tl-new did not create ./myapp in the current directory"
[ ! -e "$REPO/projects/myapp" ] || fail "tl-new wrongly created under TL_HOME/projects"

echo "== explicit TL_PROJECTS_DIR still wins (fixed home) =="
FIXED="$WORK/fixed"; mkdir -p "$FIXED"
( cd "$HERE" && TL_PROJECTS_DIR="$FIXED" "$BIN/tl-new.sh" fixedapp --yes </dev/null >/dev/null 2>&1 )
[ -d "$FIXED/fixedapp/.git" ] || fail "explicit TL_PROJECTS_DIR was not honored"
[ ! -e "$HERE/fixedapp" ]     || fail "TL_PROJECTS_DIR set but tl-new still used the CWD"

echo "PASS: tl-new defaults to the current directory; TL_PROJECTS_DIR overrides for a fixed home"
