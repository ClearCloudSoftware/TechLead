#!/usr/bin/env bash
# claude-worker.sh — a real worker backed by Claude Code headless.
# Wire it in with:  export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"
#
# Contract (same as the demo worker): read the brief from env, do the task inside the isolated
# worktree, write a markdown deliverable to $TL_REPORT (in data/, so it survives teardown), and
# record token cost. This is a thin adapter — the whole point is that the harness is swappable.
set -eu
: "${TL_TASK_ID:?}"; : "${TL_REPORT:?}"; : "${TL_WORKTREE:?}"; : "${TL_HOME:?}"
kind="${TL_TASK_KIND:-plan}"

# brief may be a file path (from --brief FILE) or an inline string
if [ -n "${TL_BRIEF:-}" ] && [ -f "$TL_BRIEF" ]; then brief="$(cat "$TL_BRIEF")"; else brief="${TL_BRIEF:-}"; fi

# plan reasons and reports; change may edit — safe here, the worktree is disposable and gated at delivery
case "$kind" in change) mode="acceptEdits";; *) mode="default";; esac

prompt="You are a TechLead worker on task $TL_TASK_ID (kind: $kind), running in an isolated,
disposable git worktree. Do the task described in the brief, then output a concise markdown
report of what you found or changed — and ONLY that report, no preamble.

Brief:
$brief"

echo "worker: launching claude ($kind) for $TL_TASK_ID"
out="$(claude -p "$prompt" --output-format json --permission-mode "$mode" --max-turns 20)" \
  || { echo "worker: claude invocation failed" >&2; "$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" failed "claude invocation failed" || true; exit 1; }

if [ "$(printf '%s' "$out" | jq -r '.is_error')" = "true" ]; then
  echo "worker: claude reported an error" >&2
  printf '%s' "$out" | jq -r '.result // "(no result)"' >&2
  "$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" failed "claude reported an error" || true
  exit 1
fi

mkdir -p "$(dirname "$TL_REPORT")"
printf '%s' "$out" | jq -r '.result' > "$TL_REPORT"

# §3.16 cost: input side includes cache read + creation tokens
in_="$(printf '%s' "$out" | jq '((.usage.input_tokens//0)+(.usage.cache_read_input_tokens//0)+(.usage.cache_creation_input_tokens//0))')"
out_="$(printf '%s' "$out" | jq '(.usage.output_tokens//0)')"
cost="$(printf '%s' "$out" | jq '(.total_cost_usd//0)')"
"$TL_HOME/bin/tl-cost.sh" record "$TL_TASK_ID" worker "$in_" "$out_" "$cost" || true
"$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" done || true   # wake-worthy transition (§3.7)

echo "worker: done ($TL_TASK_ID) — in=$in_ out=$out_ cost=$cost"
