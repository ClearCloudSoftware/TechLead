#!/usr/bin/env bash
# watch-smoke.sh — Epic 3. Proves the supervisor: classifies the fleet through the policy table,
# escalates an actionable decision with its default firing on owner silence, keeps a durable wake
# queue, and — the load-bearing bit (§3.4) — reconciles a stale event-log tail against the truth.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }

PROJ="$(mktemp -d)"; git -C "$PROJ" init -q
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
cleanup() { rm -rf "$PROJ" "$WORK"; }; trap cleanup EXIT

echo "== spawn a healthy worker and a blocking one =="
TL_WORKER_CMD="$REPO/test/demo-worker.sh"  "$BIN/tl-spawn.sh" --id ok-1  --project "$PROJ" --kind plan   --brief "ok"
TL_WORKER_CMD="$REPO/test/block-worker.sh" "$BIN/tl-spawn.sh" --id blk-1 --project "$PROJ" --kind change --brief "blocks"

echo "== run the watcher (12 ticks, ~12s; default fires on no owner) =="
TL_WATCH_INTERVAL=1 TL_FRESH_SECS=2 TL_DONE_STABLE=2 "$BIN/tl-watch.sh" 12

echo "== wake queue =="; sed 's/^/  /' "$WORK/state/.wake-queue" 2>/dev/null || echo "  (empty)"

echo "== assertions =="
Q="$WORK/state/.wake-queue"
[ -f "$Q" ] || fail "no durable wake queue (E3.2)"
awk -F'\t' '$3=="needs-decision" && $4=="blk-1"{f=1} END{exit !f}' "$Q" || fail "blk-1 needs-decision not queued"
awk -F'\t' '$3=="ready" && $4=="ok-1"{f=1} END{exit !f}' "$Q" || fail "ok-1 ready not queued"
[ "$(cat "$WORK/data/blk-1/decision" 2>/dev/null || true)" = "skip" ] || fail "escalation default (skip) did not fire (E3.6)"

# the load-bearing check (§3.4/E3.3): the event-log tail is stale, but tl-state reports the truth.
TAIL_VERB="$(tail -n1 "$WORK/state/blk-1.status" | awk -F'\t' '{print $2}')"
STATE_VERB="$("$BIN/tl-state.sh" blk-1)"
echo "  blk-1: log tail='$TAIL_VERB'  tl-state='$STATE_VERB'"
[ "$TAIL_VERB" = "needs-decision" ] || fail "expected a stale needs-decision tail, got '$TAIL_VERB'"
[ "$STATE_VERB" = "done" ] || fail "tl-state trusted the stale tail (got '$STATE_VERB', want done)"
[ "$("$BIN/tl-state.sh" ok-1)" = "done" ] || fail "ok-1 not done"

"$BIN/tl-teardown.sh" ok-1 --force >/dev/null; "$BIN/tl-teardown.sh" blk-1 --force >/dev/null
echo "PASS: fleet classified · escalation default fired · durable queue · stale tail reconciled (§3.4)"
