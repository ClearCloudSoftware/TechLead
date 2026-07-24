#!/usr/bin/env bash
# demo-worker.sh — a stand-in plan worker for the tracer bullet and smoke test.
# A real worker is a coding-agent CLI (Claude Code, Codex, …) wired in via TL_WORKER_CMD.
# Contract: read the brief from env, write the deliverable to $TL_REPORT (in data/, not the worktree).
set -eu
echo "worker: starting $TL_TASK_ID ($TL_TASK_KIND) in $TL_WORKTREE"
sleep 1
mkdir -p "$(dirname "$TL_REPORT")"
{
  echo "# Report — $TL_TASK_ID"
  echo
  echo "- Kind: $TL_TASK_KIND"
  echo "- Brief: ${TL_BRIEF:-(none)}"
  echo
  echo "## Result"
  echo "- Ran end-to-end in an isolated worktree at \`$TL_WORKTREE\`."
  echo "- Wrote this report to \`data/$TL_TASK_ID/report.md\` — it survives teardown."
} > "$TL_REPORT"
echo "worker: wrote $TL_REPORT"
echo "worker: done"
