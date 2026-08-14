#!/usr/bin/env bash
# worker-escalation-smoke.sh — E7.5/#52 producer. Proves the real claude-worker.sh escalates a
# mid-flight decision the tl-watch/tl-escalate way, parks for the owner, RESUMES the same session
# with the answer (no redone work), and that the resolved escalation feeds tl-escalation-loop into a
# lead/questions.md candidate — the whole point of the dormant loop. Token-free: TL_CLAUDE is a fake
# emitting canned JSON (an ESCALATE marker first, the final report on --resume).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"; PROJ="$(mktemp -d)"; git -C "$PROJ" init -q
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
cleanup() { rm -rf "$WORK" "$PROJ"; }; trap cleanup EXIT
ID=esc-1; D="$TL_DATA/$ID"; mkdir -p "$D"

# fake claude: a --resume call emits the report; the first call emits an ESCALATE marker + session id.
FAKE="$WORK/fake-claude.sh"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
resume=
for a in "$@"; do [ "$a" = --resume ] && resume=1; done
if [ -n "$resume" ]; then
  jq -cn '{is_error:false, result:"# Report\n\n- Used library X (owner decision).\n- Finished.", session_id:"sess-1", usage:{input_tokens:10,output_tokens:5}, total_cost_usd:0.02}'
else
  jq -cn '{is_error:false, result:"ESCALATE: Use library X or Y? ||| X", session_id:"sess-1", usage:{input_tokens:20,output_tokens:3}, total_cost_usd:0.01}'
fi
EOF
chmod +x "$FAKE"

# the owner: wait for the ask to appear, then answer via the real tl-escalate (non-interactive override).
( while [ ! -f "$D/ask" ]; do sleep 0.2; done; TL_DECISION=X "$BIN/tl-escalate.sh" "$ID" >/dev/null 2>&1 ) &

echo "== run the real worker adapter with a fake claude that escalates, then resumes =="
TL_CLAUDE="$FAKE" TL_ESCALATE_WAIT=30 \
  TL_TASK_ID="$ID" TL_TASK_KIND=plan TL_REPORT="$D/report.md" TL_WORKTREE="$PROJ" TL_BRIEF="do the thing" \
  "$REPO/adapters/claude-worker.sh" >"$WORK/w.log" 2>&1 || fail "worker errored: $(cat "$WORK/w.log")"
wait

echo "== assertions =="
grep -q 'question=Use library X or Y?' "$D/ask"                         || fail "ask file missing the escalated question"
awk -F'\t' '$2=="needs-decision"{f=1} END{exit !f}' "$TL_STATE/$ID.status" || fail "no needs-decision event logged"
awk -F'\t' '$2=="resolved" && $3=="X"{f=1} END{exit !f}' "$D/escalation.log" || fail "escalation.log has no resolved=X"
grep -q 'Used library X' "$D/report.md"                                 || fail "report is not the RESUMED result — resume didn't fire"
awk -F'\t' '$2=="done"{f=1} END{exit !f}' "$TL_STATE/$ID.status"          || fail "worker didn't log done after resume"
# cost is summed across both calls (20+10 in, 3+5 out) — the gate must not undercount (§3.16)
grep -qE '[[:space:]]worker[[:space:]]+30[[:space:]]+8[[:space:]]' "$TL_DATA/costs.tsv" || fail "cost not summed across escalation+resume (want in=30 out=8)"
echo "  ok — escalated, parked, resumed in-session; cost summed"

echo "== #52 payoff: the resolved escalation promotes into a questions.md candidate =="
TL_PROPOSE_CMD="$REPO/test/demo-propose.sh" "$BIN/tl-escalation-loop.sh" >"$WORK/loop.log" 2>&1 \
  || fail "escalation-loop errored: $(cat "$WORK/loop.log")"
ls "$TL_DATA"/proposals/question-*.md >/dev/null 2>&1 || fail "escalation-loop produced no questions.md candidate"
echo "  ok — resolved escalation became a data/proposals/ candidate (never written into lead/)"

echo "PASS: worker escalates → parks → resumes in-session; resolved escalation feeds the #52 loop into a lead/ candidate"
