#!/usr/bin/env bash
# tl-approve.sh — owner reviews a worker's deliverable and records a decision (§2.2, §1.4).
# Nothing merges or publishes automatically; this is the human gate.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"
id="${1:-$(tl_pick_task || true)}"
[ -n "$id" ] || tl_die "usage: tl-approve ID"
report="$(tl_meta_get "$id" report)" || tl_die "no such task: $id"
[ -f "$report" ] || tl_die "no report yet at $report"

echo "── report for $id ─────────────────────────────────────────"
# Paged when it does not fit: the approve/skip/fix prompt below used to push the report you are
# judging off the top of the screen — the decision and its evidence were never on screen together.
tl_page "$report"
echo "───────────────────────────────────────────────────────────"

t0="$(date +%s)"
if [ "${TL_APPROVE:-}" = "yes" ]; then
  ans="approve"
else
  # Same picker as the gate's finding resolution; TL_YES blanked so a stray wizard switch cannot
  # approve a deliverable (TL_APPROVE=yes above is the explicit non-interactive path).
  ans="$(TL_YES= tl_choose "APPROVE_$id" "approve / skip / fix ?" approve approve skip fix)"
  ans="${ans:-approve}"
fi
t1="$(date +%s)"
tl_meta_set "$id" approval "$ans"
"$BIN/tl-metric.sh" record "$id" approve "$((t1 - t0))" || true   # D13 input (E1.5)
tl_log "task $id: $ans"
echo "tl: log the counterfactual when known:  tl-metric record $id self <seconds>"
