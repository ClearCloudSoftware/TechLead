#!/usr/bin/env bash
# tl-metric.sh — the D13 metric ledger: grill time + approval time per feature, from feature 1.
# Pairs with per-rule reuse (E6.3) to evaluate the kill-gate at ~feature 15. Append-only TSV.
# tl: grill/approve rows are per-invocation wall-clock, summed by `report` — active work only, not a
#     start-to-finish span (that would count coffee breaks). `self` is a manual owner-entered
#     counterfactual — a not-done task can't be instrumented. Upgrade: none needed for the gate.
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
        printf "%-18s %9s %11s %8s %8s %-9s\n","feature","grill_s","approve_s","net_s","self_s","verdict"
        for (fe in feat) {
          g=t[fe SUBSEP "grill"]; a=t[fe SUBSEP "approve"]; s=t[fe SUBSEP "self"]; net=g+a
          v = (s==0) ? "" : (net<s ? "faster ✓" : "slower ✗")   # D13: net owner-time vs do-it-myself
          printf "%-18s %9d %11d %8d %8d %-9s\n", fe, g, a, net, s, v
        }
      }' "$LEDGER"
    ;;
  outcome)  # E6.4 — per-grill inferred-answer outcome (the risk-1 signal, §8.1). accept = an inferred
            # answer left standing; correct = owner overrode an inferred value (logged by tl-grill
            # answer). Reads specs via tl-spec (single owner, §3.1); folds in inferred-outcomes.tsv.
    log="$TL_DATA/inferred-outcomes.tsv"
    printf '%-22s %8s %8s %9s\n' "grill" "inferred" "accepted" "corrected"
    for d in "$TL_DATA"/*/; do
      id="$(basename "$d")"; [ -f "$d/spec.md" ] || continue
      acc="$("$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '$3=="inferred" && $2!="open"{c++} END{print c+0}')"
      cor="$([ -f "$log" ] && awk -F'\t' -v id="$id" '$2==id{s[$3]=1} END{n=0;for(k in s)n++;print n}' "$log" || echo 0)"
      inf=$((acc+cor)); [ "$inf" -gt 0 ] && printf '%-22s %8d %8d %9d\n' "$id" "$inf" "$acc" "$cor"
    done ;;
  *) tl_die "usage: tl-metric record <feature> grill|approve|self <seconds> | tl-metric report | tl-metric outcome";;
esac
