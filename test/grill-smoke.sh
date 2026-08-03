#!/usr/bin/env bash
# grill-smoke.sh — Epic 5. backlog -> grill (inference) -> spec; brief refuses while open; owner
# answers the delta -> specified -> brief generates; reject records "don't build this"; a stale
# answer forces re-confirmation.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_GRILL_CMD="$REPO/test/demo-grill.sh"
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT
mkdir -p "$TL_DATA"

cat > "$TL_DATA/backlog.md" <<'EOF'
# Backlog

## rotate-creds: Rotate service credentials without downtime
We need to rotate DB and API credentials with no outage window.

## drop-feature: A feature we probably should not build
EOF

echo "== grill: inference pass =="
"$BIN/tl-grill.sh" rotate-creds
ID="tl-rotate-creds"
[ "$("$BIN/tl-spec.sh" get "$ID" state)" = drafted ] || fail "expected drafted (an open question exists)"
[ "$("$BIN/tl-spec.sh" open-count "$ID")" = 1 ] || fail "expected exactly 1 open question"

echo "== brief refuses while a question is open =="
if "$BIN/tl-brief.sh" "$ID" >/tmp/gb.log 2>&1; then fail "brief did not refuse an unspecified spec"; fi
grep -q refusing /tmp/gb.log || fail "expected a refusal, got: $(cat /tmp/gb.log)"

echo "== owner answers the delta -> specified =="
"$BIN/tl-grill.sh" answer "$ID" q2 decided "Staging, then prod-eu, then prod-us"
[ "$("$BIN/tl-spec.sh" get "$ID" state)" = specified ] || fail "expected specified after answering the delta"

echo "== risk-1: overriding an inferred answer logs a correction; the delta answer did not (E6.4) =="
"$BIN/tl-grill.sh" answer "$ID" q1 decided "Introduce a dedicated secrets backend after all"
LOG="$TL_DATA/inferred-outcomes.tsv"
awk -F'\t' -v id="$ID" '$2==id && $3=="q1" && $4=="correct"{f=1} END{exit f?0:1}' "$LOG" \
  || fail "override of inferred q1 not logged as a correction"
awk -F'\t' -v id="$ID" '$2==id && $3=="q2"{f=1} END{exit f?1:0}' "$LOG" \
  || fail "answering the open delta q2 wrongly logged a correction"
[ "$("$BIN/tl-metric.sh" outcome | awk -v id="$ID" '$1==id{print $4}')" = 1 ] \
  || fail "tl-metric outcome did not report 1 correction for $ID"

echo "== brief now generates =="
"$BIN/tl-brief.sh" "$ID"
[ -f "$TL_DATA/$ID/brief.md" ] || fail "no brief.md produced"
grep -q 'MUST'  "$TL_DATA/$ID/brief.md" || fail "brief missing decided constraints"
grep -q 'SPIKE' "$TL_DATA/$ID/brief.md" || fail "brief missing the spike"

echo "== reject path: don't build this =="
"$BIN/tl-grill.sh" drop-feature >/dev/null
"$BIN/tl-grill.sh" reject tl-drop-feature "Premature — revisit after rotation lands"
[ "$("$BIN/tl-spec.sh" get tl-drop-feature state)" = rejected ] || fail "reject did not set state=rejected"
grep -qi premature "$TL_DATA/backlog.decisions" || fail "rejection not recorded against the backlog"

echo "== decay: a stale answer forces re-confirm =="
"$BIN/tl-spec.sh" qset "$ID" q1 decided inferred 2000-01-01 "old answer"
if "$BIN/tl-brief.sh" "$ID" >/tmp/gd.log 2>&1; then fail "brief did not refuse a stale answer"; fi
grep -qi 'stale\|re-confirm' /tmp/gd.log || fail "expected a decay refusal, got: $(cat /tmp/gd.log)"

echo "PASS: grill infers + asks the delta; brief refuses until specified & fresh; reject records 'do not build'"
