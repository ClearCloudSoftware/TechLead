#!/usr/bin/env bash
# tl-metric.sh — the D13 metric ledger: grill time + approval time per feature, from feature 1.
# Pairs with per-rule reuse (E6.3) to evaluate the kill-gate at ~feature 15. Append-only TSV.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
LEDGER="$TL_DATA/metrics.tsv"

case "${1:-}" in
  record)  # tl-metric record <feature> <grill|approve|self> <seconds>
    shift
    feature="${1:?feature}"; kind="${2:?kind}"; seconds="${3:?seconds}"
    printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$feature" "$kind" "$seconds" >> "$LEDGER"
    ;;
  report)
    [ -f "$LEDGER" ] || { echo "no metrics yet"; exit 0; }
    awk -F'\t' '
      { t[$2 SUBSEP $3]+=$4; feat[$2]=1 }
      END {
        printf "%-18s %9s %11s %8s\n","feature","grill_s","approve_s","self_s"
        for (fe in feat) printf "%-18s %9d %11d %8d\n", fe, t[fe SUBSEP "grill"], t[fe SUBSEP "approve"], t[fe SUBSEP "self"]
      }' "$LEDGER"
    ;;
  *) tl_die "usage: tl-metric record <feature> grill|approve|self <seconds> | tl-metric report";;
esac
