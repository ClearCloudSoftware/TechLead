#!/usr/bin/env bash
# onboard-smoke.sh — E11 setup wizards. Drives tl-init + tl-onboard + tl-new fully non-interactively
# (zero prompts, no live model) against throwaway repos and asserts they produce, via the
# single-owner scripts, a registry entry + baseline. Fast + deterministic — part of the default suite.
#
# Isolation (per TESTING.md): TL_HOME is the real repo (so $TL_HOME/bin resolves) but TL_DATA/STATE/
# WORKTREES *and* TL_CONFIG/TL_PROJECTS_DIR are redirected into a temp dir, so the real config/ and
# projects/ are never touched. `--yes` + TL_YES + </dev/null guarantee nothing can prompt or hang.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }

WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_CONFIG="$WORK/config/instance.env" TL_PROJECTS_DIR="$WORK/projects" TL_YES=1
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT

echo "== W2: tl-init writes instance.env with zero prompts =="
TL_ANSWER_HARNESS=opencode TL_ANSWER_MODEL="ollama/qwen3-coder:30b" TL_ANSWER_SEED_LEAD=n \
  "$BIN/tl-init.sh" --yes </dev/null
[ -f "$TL_CONFIG" ] || fail "tl-init did not write $TL_CONFIG"
grep -q 'opencode-worker' "$TL_CONFIG" || fail "instance.env did not record the chosen harness"
# W1 round-trip: a fresh shell with no TL_WORKER_CMD picks it up from the file
( unset TL_WORKER_CMD; . "$BIN/tl-common.sh"; case "${TL_WORKER_CMD:-}" in *opencode-worker.sh) : ;; *) exit 3;; esac ) \
  || fail "tl-common did not auto-load TL_WORKER_CMD from instance.env"
# The real lead/ now holds genuine grilled content (principles.md, etc.), so "a file exists" can't
# prove seeding ran. tl-init's stubs carry a unique marker — assert none landed in the real lead/.
if grep -rq 'stub (tl-init)' "$REPO/lead/" 2>/dev/null; then fail "tl-init seeded the REAL lead/ during the smoke (should have declined)"; fi
echo "  ok — instance.env written and auto-loaded; real lead/ untouched"

echo "== W3: tl-onboard registers a brownfield repo + baseline =="
APP="$WORK/app"; mkdir -p "$APP/migrations"
printf '#!/bin/sh\necho feat-add\necho feat-done\n' > "$APP/test.sh"; chmod +x "$APP/test.sh"
git -C "$APP" init -q -b main
git -C "$APP" -c user.email=t@t -c user.name=t add -A
git -C "$APP" -c user.email=t@t -c user.name=t commit -q -m stub
TL_ANSWER_TEST_COMMAND="sh test.sh" TL_ANSWER_GRAPH_MODE=ast "$BIN/tl-onboard.sh" "$APP" --yes </dev/null 2>"$WORK/onboard.err"

CONF="$TL_DATA/projects/app.conf"
[ -f "$CONF" ] || fail "no registry entry at $CONF"
grep -qxF "mode=local-only"            "$CONF" || fail "mode not registered"
grep -qxF "test_command=sh test.sh"    "$CONF" || fail "test_command not registered"
grep -qxF "readiness=ready"            "$CONF" || fail "readiness not promoted to ready after baseline"
grep -qxF "danger_paths=migrations/**" "$CONF" || fail "danger_paths not detected/registered"
grep -qxF "graph_mode=ast"             "$CONF" || fail "graph_mode not registered by onboard (tl-search wire)"
want="$(cd "$APP" && pwd -P)"; got="$("$BIN/tl-project.sh" get app path)"
[ "$got" = "$want" ] || fail "registered path ($got) is not the canonical toplevel ($want)"
BL="$("$BIN/tl-project.sh" get app baseline)"
[ -s "$BL" ] || fail "baseline file missing or empty"
grep -qx feat-add "$BL" && grep -qx feat-done "$BL" || fail "baseline did not capture the known-failing ids"
# W6 decline path: default is no → registered + a manual-dispatch hint, no worker spawned
grep -q "survey deferred" "$WORK/onboard.err" || fail "onboard did not offer/defer the survey hand-off (W6)"
[ -e "$TL_STATE/survey-app.meta" ] && fail "survey worker spawned despite declining" || true
echo "  ok — app registered (readiness=ready) with a 2-id baseline, path canonical, via tl-project; survey deferred"

echo "== W7: tl-new creates + registers a greenfield repo at survey =="
"$BIN/tl-new.sh" webapp --yes </dev/null
[ -d "$TL_PROJECTS_DIR/webapp/.git" ] || fail "tl-new did not create a git repo"
NCONF="$TL_DATA/projects/webapp.conf"
grep -qxF "readiness=survey" "$NCONF" || fail "greenfield not registered at survey"
grep -q  "^test_command="    "$NCONF" && fail "greenfield should have no test_command (plan-only)"
[ -n "$(git -C "$TL_PROJECTS_DIR/webapp" ls-files)" ] && fail "greenfield repo should be empty (no scaffolding)"
echo "  ok — webapp created empty and registered at survey (plan-only)"

echo "== W6: accepting the survey dispatches a plan worker (demo driver, no tokens) =="
APP2="$WORK/app2"; mkdir -p "$APP2"
printf '#!/bin/sh\necho feat-x\n' > "$APP2/test.sh"; chmod +x "$APP2/test.sh"
git -C "$APP2" init -q -b main
git -C "$APP2" -c user.email=t@t -c user.name=t add -A
git -C "$APP2" -c user.email=t@t -c user.name=t commit -q -m stub
TL_WORKER_CMD="$REPO/test/demo-worker.sh" TL_ANSWER_TEST_COMMAND="sh test.sh" TL_ANSWER_SURVEY=y TL_ANSWER_GRAPH_MODE=ast \
  "$BIN/tl-onboard.sh" "$APP2" --yes </dev/null 2>"$WORK/onboard2.err"
[ -f "$TL_STATE/survey-app2.meta" ] || fail "survey task was not dispatched on accept"
grep -qx "kind=plan" "$TL_STATE/survey-app2.meta" || fail "survey task was dispatched but not as a plan task"
grep -q "tl-search.sh build app2" "$TL_DATA/survey-app2/brief.md" || fail "graph build not a named survey deliverable (brief D2)"
i=0; while [ $i -lt 30 ]; do [ -f "$TL_DATA/survey-app2/report.md" ] && break; sleep 1; i=$((i+1)); done
[ -f "$TL_DATA/survey-app2/report.md" ] || fail "survey plan worker produced no report"
echo "  ok — survey dispatched as a plan task via tl-spawn; graph build named in the survey brief; report produced"

echo "PASS: wizards register brownfield (ready+baseline) and greenfield (survey), survey hand-off dispatches/defers, zero prompts"
