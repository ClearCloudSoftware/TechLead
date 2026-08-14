#!/usr/bin/env bash
# baseline-promote-smoke.sh — tl-baseline promotes a survey (plan-only) project to ready once a baseline
# exists (the completion criterion a `change` needs), as tl-new and the tutorial promise. Re-baselining
# an already-ready project must NOT change its readiness.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

PROJ="$WORK/proj"; mkdir -p "$PROJ"
printf '#!/bin/sh\necho reg-1\n' > "$PROJ/test.sh"   # a harness that reports one failing id
"$BIN/tl-project.sh" set p path "$PROJ"
"$BIN/tl-project.sh" set p test_command "sh test.sh"
"$BIN/tl-project.sh" set p readiness survey

echo "== survey project baselined -> promoted to ready =="
"$BIN/tl-baseline.sh" p >/dev/null
[ "$("$BIN/tl-project.sh" get p readiness)" = ready ] || fail "tl-baseline did not promote survey -> ready"

echo "== re-baselining a ready project leaves readiness alone =="
"$BIN/tl-project.sh" set p readiness assisted   # pretend it was set to a non-survey tier
"$BIN/tl-baseline.sh" p >/dev/null
[ "$("$BIN/tl-project.sh" get p readiness)" = assisted ] || fail "re-baseline wrongly changed a non-survey readiness"

echo "PASS: tl-baseline promotes survey -> ready, and never demotes/overwrites an established tier"
