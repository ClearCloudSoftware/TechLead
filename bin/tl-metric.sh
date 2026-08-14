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
      { t[$2 SUBSEP $3]+=$4; feat[$2]=1; has[$2 SUBSEP $3]=1 }   # has[]: distinguish "no data" from 0s
      END {
        for (fe in feat) {
          hg=has[fe SUBSEP "grill"]; ha=has[fe SUBSEP "approve"]; hs=has[fe SUBSEP "self"]
          g=t[fe SUBSEP "grill"]; a=t[fe SUBSEP "approve"]; s=t[fe SUBSEP "self"]
          gs=(hg?g"":"—"); as_=(ha?a"":"—"); ss=(hs?s"":"—")
          # net owner-time and the verdict need BOTH grill and approve captured, else not comparable
          if (hg && ha) { net=g+a; ns=net"" } else ns="—"
          if (!hs)                v=""
          else if (hg && ha)      v=(net<s ? "faster ✓" : "slower ✗")
          else                    v="incomplete"   # self set but grill/approve time missing (D13: not evaluable)
          printf "%s\t%s\t%s\t%s\t%s\t%s\n", fe, gs, as_, ns, ss, v
        }
      }' "$LEDGER" | tl_table "FEATURE,GRILL_S,APPROVE_S,NET_S,SELF_S,VERDICT"
    ;;
  outcome)  # E6.4 — per-grill inferred-answer outcome (the risk-1 signal, §8.1). accept = an inferred
            # answer left standing; correct = owner overrode an inferred value (logged by tl-grill
            # answer). Reads specs via tl-spec (single owner, §3.1); folds in inferred-outcomes.tsv.
    log="$TL_DATA/inferred-outcomes.tsv"
    for d in "$TL_DATA"/*/; do
      id="$(basename "$d")"; [ -f "$d/spec.md" ] || continue
      acc="$("$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '$3=="inferred" && $2!="open"{c++} END{print c+0}')"
      cor="$([ -f "$log" ] && awk -F'\t' -v id="$id" '$2==id{s[$3]=1} END{n=0;for(k in s)n++;print n}' "$log" || echo 0)"
      inf=$((acc+cor)); [ "$inf" -gt 0 ] && printf '%s\t%d\t%d\t%d\n' "$id" "$inf" "$acc" "$cor"
      true                       # a grill with nothing inferred is skipped, not a loop failure
    done | tl_table "GRILL,INFERRED,ACCEPTED,CORRECTED" ;;
  *) tl_die "usage: tl-metric record <feature> grill|approve|self <seconds> | tl-metric report | tl-metric outcome";;
esac
