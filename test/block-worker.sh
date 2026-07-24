#!/usr/bin/env bash
# block-worker.sh — a test worker that simulates hitting an ask-user finding mid-task, then
# *silently* resuming once the owner decides. Used to prove the §3.4 reconciliation: its status
# log ends on `needs-decision` forever, yet tl-state reports the true state.
set -eu
echo "worker: $TL_TASK_ID starting"
mkdir -p "$(dirname "$TL_REPORT")"

# raise a decision: write the ask, append ONE needs-decision event, then wait without logging
cat > "$TL_DATA/$TL_TASK_ID/ask" <<EOF
question=Retry exhaustion returns nil — approve / fix / skip?
default=skip
timeout=3
EOF
"$TL_HOME/bin/tl-status.sh" "$TL_TASK_ID" needs-decision "spec q3 uncovered"
# poll for the decision WITHOUT logging, so the session log mtime goes stale (the §3.4 case)
i=0; while [ $i -lt 60 ]; do [ -f "$TL_DATA/$TL_TASK_ID/decision" ] && break; sleep 1; i=$((i + 1)); done
dec="$(cat "$TL_DATA/$TL_TASK_ID/decision" 2>/dev/null || echo none)"

# silently resume and finish — deliberately NO further status event (this is the stale-tail case)
{ echo "# Report — $TL_TASK_ID"; echo; echo "- Raised spec q3; owner decided: $dec"; echo "- Resumed and finished."; } > "$TL_REPORT"
"$TL_HOME/bin/tl-cost.sh" record "$TL_TASK_ID" worker 500 100 0 || true
echo "worker: done after decision=$dec"
