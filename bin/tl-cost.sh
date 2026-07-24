#!/usr/bin/env bash
# tl-cost.sh — token/cost ledger (§3.16, §8.27). Append-only TSV, single owner of cost records.
# Recorded per task by category from task 1, so later optimisation is directed by measurement
# rather than by whichever lever is most satisfying to pull.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
LEDGER="$TL_DATA/costs.tsv"

case "${1:-}" in
  record)  # tl-cost record <id> <category> <input> <output> [cost_usd]
    shift
    id="${1:?id}"; category="${2:?category}"; in_="${3:-0}"; out_="${4:-0}"; cost="${5:-0}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$category" "$in_" "$out_" "$cost" >> "$LEDGER"
    ;;
  report)  # tl-cost report [id]
    [ -f "$LEDGER" ] || { echo "no cost records yet"; exit 0; }
    awk -F'\t' -v f="${2:-}" '
      f==""||$2==f { ci[$3]+=$4; co[$3]+=$5; cc[$3]+=($6+0); ti+=$4; to+=$5; tc+=($6+0) }
      END {
        printf "%-14s %12s %12s %12s\n","category","input","output","cost_usd"
        for (k in ci) printf "%-14s %12d %12d %12.4f\n",k,ci[k],co[k],cc[k]
        printf "%-14s %12d %12d %12.4f\n","TOTAL",ti,to,tc
      }' "$LEDGER"
    ;;
  *) tl_die "usage: tl-cost record <id> <category> <input> <output> [cost_usd] | tl-cost report [id]";;
esac
