#!/usr/bin/env bash
# feedback-smoke.sh — Epic 7 (#51, #52). The two judgment feedback loops turn a real override / worker
# escalation into an LLM-drafted CANDIDATE in data/proposals/ (outside lead/), idempotently, for the
# owner to promote. Nothing is ever written into lead/.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_PROPOSE_CMD="$REPO/test/demo-propose.sh"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT
TAB="$(printf '\t')"

echo "== #51 override loop: a grill correction -> candidate principles rule =="
# a spec whose q2 the owner corrected from inferred/leaning to decided
"$BIN/tl-spec.sh" init tl-feat rotate "Rotate creds" /dev/null
"$BIN/tl-spec.sh" qset tl-feat q2 decided owner 2026-08-10 "Introduce a dedicated secrets backend after all"
printf '%s\ttl-feat\tq2\tcorrect\tleaning->decided\n' 2026-08-10 > "$TL_DATA/inferred-outcomes.tsv"
"$BIN/tl-override-loop.sh" >/dev/null
p="$TL_DATA/proposals/rule-tl-feat-q2.md"
[ -f "$p" ] || fail "#51: no candidate rule queued"
grep -q 'Triggering case'       "$p" || fail "#51: proposal missing the triggering case"
grep -q 'leaning->decided'      "$p" || fail "#51: proposal missing the before->after"
grep -q 'dedicated secrets backend' "$p" || fail "#51: proposal missing the corrected answer"
grep -qi 'Drafted candidate'    "$p" || fail "#51: proposal missing the drafted candidate"

echo "== idempotent: re-running does not duplicate =="
before="$(ls "$TL_DATA/proposals" | wc -l | tr -d ' ')"
"$BIN/tl-override-loop.sh" >/dev/null
[ "$(ls "$TL_DATA/proposals" | wc -l | tr -d ' ')" = "$before" ] || fail "#51: re-run created a duplicate"

echo "== #52 escalation loop: a resolved escalation -> candidate question =="
mkdir -p "$TL_DATA/tl-feat"
printf 'question=Which env gets the rollout first?\ndefault=staging\ntimeout=30\n' > "$TL_DATA/tl-feat/ask"
printf '%s\tresolved\tprod-eu\n' 2026-08-10T10:00:00Z > "$TL_DATA/tl-feat/escalation.log"
"$BIN/tl-escalation-loop.sh" >/dev/null
q="$TL_DATA/proposals/question-tl-feat-1.md"
[ -f "$q" ] || fail "#52: no candidate question queued"
grep -q 'rollout first'  "$q" || fail "#52: proposal missing the worker's question"
grep -qi 'scar'          "$q" || fail "#52: proposal missing the scar"

echo "== dormant when there are no escalations =="
rm -rf "$TL_DATA/tl-feat/escalation.log"; rm -rf "$WORK/data2"; TL_DATA2="$WORK/data2"
TL_DATA="$WORK/data2" TL_STATE="$WORK/s2" "$BIN/tl-escalation-loop.sh" | grep -qi 'ready' || fail "#52: not dormant-safe with no escalations"

echo "== propose-not-write: candidates live OUTSIDE lead/, nothing touched in lead/ =="
case "$p" in "$TL_HOME"/lead/*) fail "proposal written into lead/ (must be data/proposals/)";; esac
[ -z "$(git -C "$TL_HOME" status --porcelain lead/ 2>/dev/null)" ] || fail "the loops modified lead/"

echo "PASS: override->rule + escalation->question, drafted to data/proposals/, idempotent, lead/ untouched"
