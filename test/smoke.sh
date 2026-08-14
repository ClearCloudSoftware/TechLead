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
HOME_="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO"                                  # real instance: has bin/ and AGENTS.md
export TL_DATA="$HOME_/data" TL_STATE="$HOME_/state" TL_WORKTREES="$HOME_/state/wt"
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
[ -f "$HOME_/data/costs.tsv" ] || fail "no cost ledger (E1.4)"
awk -F'\t' -v id="$ID" '$2==id{f=1} END{exit !f}' "$HOME_/data/costs.tsv" || fail "cost not recorded for $ID"
[ -f "$HOME_/data/metrics.tsv" ] || fail "no metric ledger (E1.5)"
awk -F'\t' -v id="$ID" '$2==id && $3=="approve"{f=1} END{exit !f}' "$HOME_/data/metrics.tsv" || fail "approval time not recorded for $ID"

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

echo "== ledgers =="
"$BIN/tl-cost.sh" report | sed 's/^/  /'
"$BIN/tl-metric.sh" report | sed 's/^/  /'

echo "PASS: dispatch → worktree → report → approve → teardown; guard refuses undelivered work; cost + metric recorded"
