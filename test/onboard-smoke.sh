#!/usr/bin/env bash
# onboard-smoke.sh — E11 setup wizards. Drives tl-init + tl-onboard + tl-new fully non-interactively
# (zero prompts, no live model) against throwaway repos and asserts they produce, via the
# single-owner scripts, a registry entry + baseline. Fast + deterministic — part of the default suite.
#
# Isolation: TL_HOME is the real repo (so $TL_HOME/bin resolves) but TL_DATA/STATE/
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
TL_ANSWER_HARNESS=opencode TL_ANSWER_MODEL="ollama/qwen3-coder:30b" \
  "$BIN/tl-init.sh" --yes </dev/null
[ -f "$TL_CONFIG" ] || fail "tl-init did not write $TL_CONFIG"
grep -q 'opencode-worker' "$TL_CONFIG" || fail "instance.env did not record the chosen harness"
# W1 round-trip: a fresh shell with no TL_WORKER_CMD picks it up from the file
( unset TL_WORKER_CMD; . "$BIN/tl-common.sh"; case "${TL_WORKER_CMD:-}" in *opencode-worker.sh) : ;; *) exit 3;; esac ) \
  || fail "tl-common did not auto-load TL_WORKER_CMD from instance.env"
# tl-init no longer touches lead/ at all (per-project now — tl-new/tl-onboard scaffold each repo's
# own .techlead/lead). The scaffold stubs carry a unique marker — assert none landed in the real lead/.
if grep -rq 'stub (tl-scaffold)' "$REPO/lead/" 2>/dev/null; then fail "the smoke seeded the REAL lead/ (should stay per-project/temp)"; fi
echo "  ok — instance.env written and auto-loaded; real lead/ untouched"

echo "== W3: tl-onboard registers a brownfield repo + baseline =="
APP="$WORK/app"; mkdir -p "$APP/migrations"
printf '#!/bin/sh\necho feat-add\necho feat-done\n' > "$APP/test.sh"; chmod +x "$APP/test.sh"
git -C "$APP" init -q -b main
git -C "$APP" -c user.email=t@t -c user.name=t add -A
git -C "$APP" -c user.email=t@t -c user.name=t commit -q -m stub
TL_ANSWER_TEST_COMMAND="sh test.sh" "$BIN/tl-onboard.sh" "$APP" --yes </dev/null 2>"$WORK/onboard.err"

# Per-project state (owner decision 2026-08-14): the registry + baseline + state live in the
# onboarded repo's own .techlead/, NOT the central TL_DATA. Read them from there.
APP_DATA="$APP/.techlead/data"; APP_STATE="$APP/.techlead/state"
pget() { TL_DATA="$APP_DATA" TL_STATE="$APP_STATE" "$BIN/tl-project.sh" get app "$1"; }
CONF="$APP_DATA/projects/app.conf"
[ -f "$CONF" ] || fail "no registry entry at $CONF"
[ -e "$TL_DATA/projects/app.conf" ] && fail "registry leaked into central TL_DATA (should be per-project)" || true
grep -qxF "mode=local-only"            "$CONF" || fail "mode not registered"
grep -qxF "test_command=sh test.sh"    "$CONF" || fail "test_command not registered"
grep -qxF "readiness=ready"            "$CONF" || fail "readiness not promoted to ready after baseline"
grep -qxF "danger_paths=migrations/**" "$CONF" || fail "danger_paths not detected/registered"
want="$(cd "$APP" && pwd -P)"; got="$(pget path)"
[ "$got" = "$want" ] || fail "registered path ($got) is not the canonical toplevel ($want)"
BL="$(pget baseline)"
[ -s "$BL" ] || fail "baseline file missing or empty"
grep -qx feat-add "$BL" && grep -qx feat-done "$BL" || fail "baseline did not capture the known-failing ids"
# .techlead/ kept out of the repo's history (like .claude/.superpowers)
grep -qxF '.techlead/' "$APP/.gitignore" || fail "onboard did not gitignore .techlead/"
# W6 decline path: default is no → registered + a manual-dispatch hint, no worker spawned
grep -q "survey deferred" "$WORK/onboard.err" || fail "onboard did not offer/defer the survey hand-off (W6)"
[ -e "$APP_STATE/survey-app.meta" ] && fail "survey worker spawned despite declining" || true
echo "  ok — app registered (readiness=ready) with a 2-id baseline, path canonical, via tl-project; survey deferred"

echo "== W7: tl-new creates + registers a greenfield repo at survey =="
"$BIN/tl-new.sh" webapp --yes </dev/null
WEBAPP="$TL_PROJECTS_DIR/webapp"
[ -d "$WEBAPP/.git" ] || fail "tl-new did not create a git repo"
NCONF="$WEBAPP/.techlead/data/projects/webapp.conf"
grep -qxF "readiness=survey" "$NCONF" || fail "greenfield not registered at survey"
grep -q  "^test_command="    "$NCONF" && fail "greenfield should have no test_command (plan-only)"
# .techlead/ is gitignored and never staged → the repo itself stays empty (no scaffolding committed)
[ -n "$(git -C "$WEBAPP" ls-files)" ] && fail "greenfield repo should be empty (no scaffolding)"
echo "  ok — webapp created empty and registered at survey (plan-only)"

echo "== W6: accepting the survey dispatches a plan worker (demo driver, no tokens) =="
APP2="$WORK/app2"; mkdir -p "$APP2"
printf '#!/bin/sh\necho feat-x\n' > "$APP2/test.sh"; chmod +x "$APP2/test.sh"
git -C "$APP2" init -q -b main
git -C "$APP2" -c user.email=t@t -c user.name=t add -A
git -C "$APP2" -c user.email=t@t -c user.name=t commit -q -m stub
TL_WORKER_CMD="$REPO/test/demo-worker.sh" TL_ANSWER_TEST_COMMAND="sh test.sh" TL_ANSWER_SURVEY=y \
  "$BIN/tl-onboard.sh" "$APP2" --yes </dev/null 2>"$WORK/onboard2.err"
APP2_DATA="$APP2/.techlead/data"; APP2_STATE="$APP2/.techlead/state"
[ -f "$APP2_STATE/survey-app2.meta" ] || fail "survey task was not dispatched on accept"
grep -qx "kind=plan" "$APP2_STATE/survey-app2.meta" || fail "survey task was dispatched but not as a plan task"
i=0; while [ $i -lt 30 ]; do [ -f "$APP2_DATA/survey-app2/report.md" ] && break; sleep 1; i=$((i+1)); done
[ -f "$APP2_DATA/survey-app2/report.md" ] || fail "survey plan worker produced no report"
echo "  ok — survey dispatched as a plan task via tl-spawn; report produced"

echo "PASS: wizards register brownfield (ready+baseline) and greenfield (survey), survey hand-off dispatches/defers, zero prompts"
