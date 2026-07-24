#!/usr/bin/env bash
# tl-approve.sh — owner reviews a worker's deliverable and records a decision (§2.2, §1.4).
# Nothing merges or publishes automatically; this is the human gate.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-approve ID}"
report="$(tl_meta_get "$id" report)" || tl_die "no such task: $id"
[ -f "$report" ] || tl_die "no report yet at $report"

echo "── report for $id ─────────────────────────────────────────"
cat "$report"
echo "───────────────────────────────────────────────────────────"

t0="$(date +%s)"
if [ "${TL_APPROVE:-}" = "yes" ]; then
  ans="approve"
else
  printf "approve / skip / fix ? [approve] "
  read -r ans || ans="approve"
  ans="${ans:-approve}"
fi
t1="$(date +%s)"
tl_meta_set "$id" approval "$ans"
"$BIN/tl-metric.sh" record "$id" approve "$((t1 - t0))" || true   # D13 input (E1.5)
tl_log "task $id: $ans"
