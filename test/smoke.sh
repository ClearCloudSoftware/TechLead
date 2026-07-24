#!/usr/bin/env bash
# smoke.sh — the Phase 0 tracer bullet, end to end:
# dispatch a plan task -> isolated worktree -> report -> approve -> teardown.
# Asserts the worktree is gone and the report survived. No tmux, no network, no real LLM.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO/bin"
ID="smoke-1"

fail() { echo "FAIL: $1"; exit 1; }

# temp project the worker gets a worktree of
PROJ="$(mktemp -d)"; git -C "$PROJ" init -q
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
# temp instance home (isolates data/ state/ from the real repo) with the TL_HOME marker
HOME_="$(mktemp -d)"; cp "$REPO/AGENTS.md" "$HOME_/AGENTS.md"
export TL_HOME="$HOME_"
export TL_WORKER_CMD="$REPO/test/demo-worker.sh"
cleanup() { rm -rf "$PROJ" "$HOME_"; }
trap cleanup EXIT

echo "== spawn =="
"$BIN/tl-spawn.sh" --id "$ID" --project "$PROJ" --kind plan --brief "Prove the dispatch loop."

echo "== wait for worker =="
i=0; while [ $i -lt 30 ]; do [ -f "$HOME_/data/$ID/report.md" ] && break; sleep 1; i=$((i+1)); done
[ -f "$HOME_/data/$ID/report.md" ] || fail "no report produced"

echo "== peek =="
"$BIN/tl-peek.sh" "$ID" | sed 's/^/  /'

echo "== send (best-effort mailbox) =="
"$BIN/tl-send.sh" "$ID" "noted"

echo "== approve =="
TL_APPROVE=yes "$BIN/tl-approve.sh" "$ID" >/dev/null

echo "== teardown =="
"$BIN/tl-teardown.sh" "$ID"

echo "== assertions =="
[ -f "$HOME_/data/$ID/report.md" ] || fail "report did not survive teardown"
[ ! -e "$HOME_/state/wt/$ID" ] || fail "worktree dir not removed"
git -C "$PROJ" worktree list | grep -q "wt/$ID" && fail "worktree still registered in git" || true

echo "== guard: teardown refuses undelivered work =="
G="smoke-2"
"$BIN/tl-spawn.sh" --id "$G" --project "$PROJ" --kind change --brief "guard check"
i=0; while [ $i -lt 30 ]; do [ -f "$HOME_/data/$G/report.md" ] && break; sleep 1; i=$((i+1)); done
GWT="$(grep '^worktree=' "$HOME_/state/$G.meta" | cut -d= -f2-)"
echo "dirty" > "$GWT/uncommitted.txt"                 # work not yet delivered
if "$BIN/tl-teardown.sh" "$G" >/dev/null 2>&1; then fail "teardown did NOT refuse a dirty worktree"; fi
echo "  refused as expected; forcing cleanup"
"$BIN/tl-teardown.sh" "$G" --force >/dev/null
[ ! -e "$HOME_/state/wt/$G" ] || fail "forced teardown left the worktree behind"

echo "PASS: dispatch → worktree → report → approve → teardown, and the guard refuses undelivered work"
