#!/usr/bin/env bash
# claude-worker.sh — a real worker backed by Claude Code headless.
# Wire it in with:  export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"
#
# Contract (same as the demo worker): read the brief from env, do the task inside the isolated
# worktree, write a markdown deliverable to $TL_REPORT (in data/, so it survives teardown), and
# record token cost. This is a thin adapter — the whole point is that the harness is swappable.
#
# Escalation (E7.5/#52): a worker that hits a decision only the owner should make must NOT guess.
# The prompt tells it to emit one line — `ESCALATE: <question> ||| <default>` — instead of a report.
# We raise it the way tl-watch/tl-escalate expect (write data/<id>/ask, emit needs-decision), park
# for the owner's answer (data/<id>/decision — the stated default fires on silence, §2.3/D8), then
# RESUME the same claude session with the decision so no work is redone. Each resolved escalation is
# what tl-escalation-loop later promotes into a lead/questions.md candidate — that loop was built
# dormant, waiting for exactly this producer.
set -eu
: "${TL_TASK_ID:?}"; : "${TL_REPORT:?}"; : "${TL_WORKTREE:?}"; : "${TL_HOME:?}"
kind="${TL_TASK_KIND:-plan}"
CLAUDE="${TL_CLAUDE:-claude}"          # swappable for tests (a fake emitting canned JSON)
D="$TL_DATA/$TL_TASK_ID"; mkdir -p "$D" "$(dirname "$TL_REPORT")"

# brief may be a file path (from --brief FILE) or an inline string
if [ -n "${TL_BRIEF:-}" ] && [ -f "$TL_BRIEF" ]; then brief="$(cat "$TL_BRIEF")"; else brief="${TL_BRIEF:-}"; fi

# plan reasons and reports; change may edit — safe here, the worktree is disposable and gated at delivery
case "$kind" in change) mode="acceptEdits";; *) mode="default";; esac

prompt="You are a TechLead worker on task $TL_TASK_ID (kind: $kind), running in an isolated,
disposable git worktree. Do the task described in the brief, then output a concise markdown
report of what you found or changed — and ONLY that report, no preamble.

If you reach a decision that only the owner should make — a fork the brief does not resolve, or a
change to a danger path — do NOT guess. Output EXACTLY one line and nothing else:
  ESCALATE: <the question, one line> ||| <the safe default if the owner stays silent>
You will be resumed with the owner's answer and should then continue.

Brief:
$brief"

fail() { echo "worker: $1" >&2; "$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" failed "$1" || true; exit 1; }

# Running cost totals across the initial call + every resume (§3.16 — the D13 gate must not undercount;
# a per-call total_cost_usd would drop everything before the last escalation).
tin=0; tout=0; tcost=0
acc_cost() { # <claude-json>
  local j="$1"
  tin=$(( tin + $(printf '%s' "$j" | jq '((.usage.input_tokens//0)+(.usage.cache_read_input_tokens//0)+(.usage.cache_creation_input_tokens//0))') ))
  tout=$(( tout + $(printf '%s' "$j" | jq '(.usage.output_tokens//0)') ))
  tcost=$(printf '%s' "$j" | jq -r --argjson c "$tcost" '$c + (.total_cost_usd//0)')
}

echo "worker: launching claude ($kind) for $TL_TASK_ID"
out="$($CLAUDE -p "$prompt" --output-format json --permission-mode "$mode" --max-turns 20 </dev/null)" \
  || fail "claude invocation failed"

esc=0; MAX_ESC="${TL_MAX_ESCALATIONS:-5}"
while :; do
  [ "$(printf '%s' "$out" | jq -r '.is_error')" = "true" ] \
    && { printf '%s' "$out" | jq -r '.result // "(no result)"' >&2; fail "claude reported an error"; }
  acc_cost "$out"
  result="$(printf '%s' "$out" | jq -r '.result')"
  session="$(printf '%s' "$out" | jq -r '.session_id // empty')"

  # A leading `ESCALATE:` line is the only escalation signal; anything else is the final report.
  marker="$(printf '%s\n' "$result" | grep -m1 '^ESCALATE:' || true)"
  [ -n "$marker" ] || break

  esc=$((esc+1)); [ "$esc" -gt "$MAX_ESC" ] && fail "too many escalations (>$MAX_ESC) — failing closed"
  [ -n "$session" ] || fail "escalation but no session_id to resume"

  rest="${marker#ESCALATE:}"
  question="$(printf '%s' "$rest" | awk -F'\\|\\|\\|' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  default="$(printf '%s' "$rest" | awk -F'\\|\\|\\|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "$question" ] || question="worker needs a decision (no question text)"
  [ -n "$default" ] || default="proceed"      # park-don't-block needs a default to fire (§2.3)

  # Clear any stale decision FIRST so we read THIS round's answer, then raise it and park.
  rm -f "$D/decision"
  { printf 'question=%s\n' "$question"; printf 'default=%s\n' "$default"
    printf 'timeout=%s\n' "${TL_ESCALATE_TIMEOUT:-300}"; } > "$D/ask"
  "$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" needs-decision "$question" || true
  echo "worker: escalated [$TL_TASK_ID] $question (default: $default) — parking for owner" >&2

  # tl-escalate writes data/<id>/decision (the default fires there on owner silence). Poll for it; if
  # nothing answers within our own wait, fall to the stated default so a headless run never hangs.
  i=0; dec=""
  while [ "$i" -lt "${TL_ESCALATE_WAIT:-600}" ]; do
    [ -f "$D/decision" ] && { dec="$(cat "$D/decision")"; break; }
    sleep 1; i=$((i+1))
  done
  [ -n "$dec" ] || dec="$default"
  echo "worker: resuming [$TL_TASK_ID] with decision: $dec" >&2

  out="$($CLAUDE -p --resume "$session" "The owner decided: $dec. Continue the task from where you paused. If you hit another owner-only decision, escalate the same way (ESCALATE: <question> ||| <default>); otherwise output ONLY the final markdown report." --output-format json --permission-mode "$mode" --max-turns 20 </dev/null)" \
    || fail "claude resume failed"
done

printf '%s' "$result" > "$TL_REPORT"

# change tasks: commit whatever claude edited so the delivery gate sees a diff on tl/<id>
if [ "$kind" = change ] && [ -n "$(git -C "$TL_WORKTREE" status --porcelain 2>/dev/null)" ]; then
  git -C "$TL_WORKTREE" add -A
  git -C "$TL_WORKTREE" -c user.email=worker@techlead -c user.name="tl worker" commit -q -m "change: $TL_TASK_ID"
  echo "worker: committed edits on $(git -C "$TL_WORKTREE" rev-parse --abbrev-ref HEAD)"
fi

"$TL_HOME/bin/tl-cost.sh" record "$TL_TASK_ID" worker "$tin" "$tout" "$tcost" || true
"$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" done || true   # wake-worthy transition (§3.7)
echo "worker: done ($TL_TASK_ID) — in=$tin out=$tout cost=$tcost (escalations=$esc)"
