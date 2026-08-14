#!/usr/bin/env bash
# soak-fixes-smoke.sh — the three bugs the dogfood soak exposed:
#  #5 every LLM adapter records cost (tl-cost record-json parses a claude JSON envelope), not just the worker.
#  #4 tl-metric report distinguishes "no data captured" (—) from "0 seconds", and won't render a verdict
#     from incomplete timing.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

echo "== #5: record-json parses a claude -p envelope and books the cost by category =="
printf '%s' '{"result":"ok","usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":50},"total_cost_usd":0.42}' \
  | "$BIN/tl-cost.sh" record-json tl-x answer
row="$(grep 'answer' "$TL_DATA/costs.tsv")"
printf '%s' "$row" | grep -q 'tl-x' || fail "#5: cost not attributed to the id"
[ "$("$BIN/tl-cost.sh" report | awk '$1=="answer"{print $2}')" = 1000 ] || fail "#5: input (incl cache) not summed to 1000"
[ "$("$BIN/tl-cost.sh" report | awk '$1=="answer"{print $4}')" = "0.4200" ] || fail "#5: cost_usd not recorded"

echo "== #4: 'no data' shows — not 0; verdict withheld when timing is incomplete =="
: > "$TL_DATA/metrics.tsv"
printf '2026-08-10T00:00:00Z\tfeat-a\tapprove\t0\n' >> "$TL_DATA/metrics.tsv"   # approve only, no grill (the soak case)
printf '2026-08-10T00:00:00Z\tfeat-a\tself\t600\n'  >> "$TL_DATA/metrics.tsv"
printf '2026-08-10T00:00:00Z\tfeat-b\tgrill\t120\n' >> "$TL_DATA/metrics.tsv"   # complete
printf '2026-08-10T00:00:00Z\tfeat-b\tapprove\t30\n'>> "$TL_DATA/metrics.tsv"
printf '2026-08-10T00:00:00Z\tfeat-b\tself\t900\n'  >> "$TL_DATA/metrics.tsv"
rep="$("$BIN/tl-metric.sh" report)"
printf '%s' "$rep" | awk '$1=="feat-a"{print $2}' | grep -q '—'          || fail "#4: missing grill shown as 0, not —"
printf '%s' "$rep" | awk '$1=="feat-a"{print $6}' | grep -q 'incomplete' || fail "#4: verdict not withheld on incomplete timing"
printf '%s' "$rep" | awk '$1=="feat-b"{print $6}' | grep -q 'faster'     || fail "#4: complete feature lost its verdict"

echo "PASS: LLM adapters book cost by category; metric distinguishes no-data from 0 and withholds bad verdicts"
