#!/usr/bin/env bash
# tl-grill.sh — MECHANICS ONLY (§2.4, §3.10). Resolves a backlog item, allocates the task id,
# scaffolds spec.md, runs the inference pass by handing lead/questions.md + prior decisions/ to a
# grill driver, and validates structured fields. It never reads prose to decide whether a question
# is answered — question selection and phrasing are semantic policy in lead/questions.md.
#
# Subcommands: <slug> (grill) · answer ID QID STATE [text] · reject ID reason · show ID
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
BACKLOG="${TL_BACKLOG:-$TL_DATA/backlog.md}"
TAB="$(printf '\t')"

slugify() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'; }

_finalize() {  # id — set state from open-count, then report
  local id="$1" open
  open="$("$BIN/tl-spec.sh" open-count "$id")"
  if [ "$open" -eq 0 ]; then "$BIN/tl-spec.sh" set "$id" state specified
  else "$BIN/tl-spec.sh" set "$id" state drafted; fi
  echo "tl: $id — state=$("$BIN/tl-spec.sh" get "$id" state), $open open question(s)"
  "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '{printf "  [%s] %-8s %-8s %s\n",$1,$2,$3,$5}'
  [ "$open" -gt 0 ] && echo "tl: answer the delta:  tl-grill answer $id <qid> <decided|leaning|spike> [text]" || true
}

case "${1:-}" in
  answer)  # answer ID QID STATE [text...]
    id="${2:?}"; qid="${3:?}"; st="${4:?}"; shift 4 || true
    t0="$(date +%s)"
    [ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id"
    cur="$("$BIN/tl-spec.sh" qlist "$id" | awk -F'|' -v q="$qid" '$1==q{print;exit}')"
    [ -n "$cur" ] || tl_die "no such question $qid in $id"
    case "$st" in decided|leaning|open|spike) ;; *) tl_die "answer_state must be decided|leaning|open|spike";; esac
    text="${*:-$(printf '%s' "$cur" | awk -F'|' '{print $5}')}"
    # E6.4 risk-1 data (§2.6, §8.1): overriding an inferred *value* (not an open delta) is a labeled
    # correction — log it. accepts are latent (source stays `inferred`); tl-metric outcome folds both.
    psrc="$(printf '%s' "$cur" | awk -F'|' '{print $3}')"; pstate="$(printf '%s' "$cur" | awk -F'|' '{print $2}')"
    case "$psrc:$pstate" in
      inferred:decided|inferred:leaning|inferred:spike)
        printf '%s\t%s\t%s\tcorrect\t%s\n' "$(date -u +%Y-%m-%d)" "$id" "$qid" "$pstate->$st" \
          >> "$TL_DATA/inferred-outcomes.tsv" ;;
    esac
    "$BIN/tl-spec.sh" qset "$id" "$qid" "$st" owner "$(date -u +%Y-%m-%d)" "$text"
    "$BIN/tl-metric.sh" record "$id" grill "$(( $(date +%s) - t0 ))" || true   # D13 input (E1.5)
    _finalize "$id"; exit 0 ;;
  reject)  # reject ID reason...  — terminal "don't build this" (D10, §7.3)
    id="${2:?}"; shift 2 || true; reason="${*:-unspecified}"
    [ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id"
    "$BIN/tl-spec.sh" set "$id" state rejected
    printf '\n## Rejected\n\n%s\n' "$reason" >> "$("$BIN/tl-spec.sh" path "$id")"
    printf '%s\trejected\t%s\t%s\n' "$(date -u +%Y-%m-%d)" "$("$BIN/tl-spec.sh" get "$id" backlog)" "$reason" \
      >> "$TL_DATA/backlog.decisions"
    tl_log "grill: rejected $id — $reason"; exit 0 ;;
  show) cat "$("$BIN/tl-spec.sh" path "${2:?}")"; exit 0 ;;
esac

# ---- default: start/refresh a grill for a backlog slug ----
slug="${1:?usage: tl-grill <backlog-slug> | answer|reject|show ...}"
t0="$(date +%s)"
[ -f "$BACKLOG" ] || tl_die "no backlog at $BACKLOG"
title="$(awk -v s="$slug" 'index($0,"## "s":")==1{t=$0; sub("^## [^:]*: *","",t); print t; exit}' "$BACKLOG")"
[ -n "$title" ] || tl_die "backlog item '$slug' not found (want a heading '## $slug: <title>')"
bodyf="$(mktemp)"
awk -v s="$slug" 'index($0,"## "s":")==1{f=1;next} f&&index($0,"## ")==1{f=0} f{print}' "$BACKLOG" > "$bodyf"

id="tl-$(slugify "$slug")"
[ -f "$("$BIN/tl-spec.sh" path "$id")" ] || "$BIN/tl-spec.sh" init "$id" "$slug" "$title" "$bodyf"
tl_log "grill: $id — inference pass over lead/questions.md"

: "${TL_GRILL_CMD:?tl: no grill driver — set TL_GRILL_CMD (e.g. adapters/claude-grill.sh)}"
# driver emits one line per question:  qid <TAB> answer_state <TAB> source <TAB> text
TL_GRILL_ID="$id" TL_GRILL_SLUG="$slug" TL_GRILL_TITLE="$title" TL_GRILL_BODY="$bodyf" \
TL_QUESTIONS="$TL_HOME/lead/questions.md" TL_DECISIONS="$TL_HOME/lead/decisions" \
  $TL_GRILL_CMD | while IFS="$TAB" read -r qid st src text; do
    [ -n "$qid" ] || continue
    case "$st"  in decided|leaning|open|spike) ;; *) st=open;;  esac   # validate; unknown -> open (fail closed)
    case "$src" in owner|inferred) ;; *) src=inferred;; esac
    "$BIN/tl-spec.sh" qset "$id" "$qid" "$st" "$src" "$(date -u +%Y-%m-%d)" "$text"
  done
rm -f "$bodyf"
"$BIN/tl-metric.sh" record "$id" grill "$(( $(date +%s) - t0 ))" || true   # D13 input (E1.5)
_finalize "$id"
