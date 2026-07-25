#!/usr/bin/env bash
# opencode-worker.sh — a worker backed by opencode (https://opencode.ai) instead of Claude Code.
# The agent harness is a seam: nothing in bin/ knows which one runs. Wire with:
#   export TL_WORKER_CMD="$TL_HOME/adapters/opencode-worker.sh"
#   export TL_OPENCODE_MODEL="ollama/qwen3-coder:30b"     # any TOOLS-CAPABLE model
#
# Same contract as the Claude adapter: do the task in the isolated worktree, write the deliverable
# to $TL_REPORT, commit edits for change tasks, record cost. Note: opencode needs a model that
# supports tool/function calling (a code model like qwen3-coder, not e.g. deepseek-coder-heretic).
# Local models cost nothing, so cost is recorded as 0.
set -eu
: "${TL_TASK_ID:?}"; : "${TL_REPORT:?}"; : "${TL_WORKTREE:?}"; : "${TL_HOME:?}"
kind="${TL_TASK_KIND:-plan}"
model="${TL_OPENCODE_MODEL:-ollama/qwen3-coder:30b}"

if [ -n "${TL_BRIEF:-}" ] && [ -f "$TL_BRIEF" ]; then brief="$(cat "$TL_BRIEF")"; else brief="${TL_BRIEF:-}"; fi

prompt="You are a TechLead worker on task $TL_TASK_ID (kind: $kind), running in an isolated,
disposable git worktree. Do the task described in the brief, then print a short markdown report of
what you found or changed — only the report.

Brief:
$brief"

echo "worker: launching opencode ($kind, $model) for $TL_TASK_ID"
out="$(opencode run "$prompt" --model "$model" --dir "$TL_WORKTREE" </dev/null)" \
  || { echo "worker: opencode invocation failed" >&2; "$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" failed "opencode failed" || true; exit 1; }

mkdir -p "$(dirname "$TL_REPORT")"
printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' > "$TL_REPORT"   # strip any ANSI

# change tasks: commit whatever opencode edited so the delivery gate sees a diff on tl/<id>
if [ "$kind" = change ] && [ -n "$(git -C "$TL_WORKTREE" status --porcelain 2>/dev/null)" ]; then
  git -C "$TL_WORKTREE" add -A
  git -C "$TL_WORKTREE" -c user.email=worker@techlead -c user.name="tl worker" commit -q -m "change: $TL_TASK_ID"
  echo "worker: committed edits on $(git -C "$TL_WORKTREE" rev-parse --abbrev-ref HEAD)"
fi

"$TL_HOME/bin/tl-cost.sh" record "$TL_TASK_ID" worker 0 0 0 || true    # local/opencode: no API cost tracked here
"$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" done || true
echo "worker: done ($TL_TASK_ID)"
