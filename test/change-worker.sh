#!/usr/bin/env bash
# change-worker.sh — a test change worker: edits file(s) in its worktree and commits on tl/<id>.
# Controlled by env: TL_CW_FILES (space-separated relative paths), TL_CW_MSG.
set -eu
cd "$TL_WORKTREE"
files="${TL_CW_FILES:-hello.txt}"
for f in $files; do mkdir -p "$(dirname "$f")"; printf 'change by %s\n' "$TL_TASK_ID" > "$f"; git add "$f"; done
git -c user.email=w@w -c user.name=worker commit -q -m "${TL_CW_MSG:-change: $TL_TASK_ID}"
mkdir -p "$(dirname "$TL_REPORT")"
{ echo "# Report — $TL_TASK_ID"; echo; echo "Changed: $files"; } > "$TL_REPORT"
"$TL_HOME/bin/tl-cost.sh" record "$TL_TASK_ID" worker 800 150 0 || true
"$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" done || true
echo "worker: committed change on $(git rev-parse --abbrev-ref HEAD) — $files"
