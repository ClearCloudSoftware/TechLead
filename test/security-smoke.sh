#!/usr/bin/env bash
# security-smoke.sh — the Security review axis. Owner decision 2026-08-18: security BLOCKS at the
# delivery gate, standards stays advisory (#53 q2 holds). Proves:
#   A. a security finding blocks the gate (headless fail-closed) and is classified ask-user
#   B. a crashed judge blocks too (security-unrunnable — never a silent pass)
#   C. malformed judge output blocks (nothing usable survived the filter)
#   D. a clean judge passes the gate with zero findings
#   E. the review draft gains a Security section; standards rules never reach findings.json
#   F. no TL_SECURITY_CMD configured -> axis skipped, gate unaffected (bootstrap ceiling)
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

id=tl-sec-demo
"$BIN/tl-project.sh" set secproj path "$WORK"   # registry entry so the gate's pget degrades cleanly
WT="$WORK/wt"; mkdir -p "$WT"; git -C "$WT" init -q -b main
echo base > "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
echo changed >> "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change; tl_meta_set "$id" pname secproj

gate() { "$BIN/tl-gate.sh" "$id"; }
export TL_SECURITY_CMD="$REPO/test/demo-security.sh"

echo "== A. security finding blocks the gate =="
if TL_DEMO_SEC_MODE=findings gate >/tmp/sec-a.log 2>&1; then fail "A: gate passed despite a security finding"; fi
grep -q 'gate blocked' /tmp/sec-a.log || fail "A: expected a gate block, got: $(cat /tmp/sec-a.log)"
jq -e '.[]|select(.rule=="security-vulnerability" and .class=="ask-user")' "$TL_DATA/$id/findings.json" >/dev/null \
  || fail "A: no ask-user security-vulnerability finding in findings.json"
echo "  A ok — security finding blocks, classified ask-user"

echo "== B. crashed judge blocks (fail closed) =="
if TL_DEMO_SEC_MODE=crash gate >/tmp/sec-b.log 2>&1; then fail "B: gate passed despite a crashed security judge"; fi
jq -e '.[]|select(.rule=="security-unrunnable")' "$TL_DATA/$id/findings.json" >/dev/null \
  || fail "B: no security-unrunnable finding after a judge crash"
echo "  B ok — dead reviewer blocks, never silently passes"

echo "== C. malformed judge output blocks =="
if TL_DEMO_SEC_MODE=malformed gate >/tmp/sec-c.log 2>&1; then fail "C: gate passed despite malformed judge output"; fi
jq -e '.[]|select(.rule=="security-unrunnable")' "$TL_DATA/$id/findings.json" >/dev/null \
  || fail "C: malformed output did not surface as security-unrunnable"
echo "  C ok — malformed output fails closed"

echo "== D. clean judge passes the gate =="
TL_DEMO_SEC_MODE=clean gate >/tmp/sec-d.log 2>&1 || fail "D: gate blocked on a clean security review: $(cat /tmp/sec-d.log)"
jq -e 'length==0' "$TL_DATA/$id/findings.json" >/dev/null || fail "D: clean review still produced findings"
echo "  D ok — clean review, gate passes"

echo "== E. review draft gains a Security section; standards stays advisory =="
"$BIN/tl-spec.sh" init "$id" sec-demo "Security demo" /dev/null
"$BIN/tl-spec.sh" qset "$id" q1 decided owner 2026-08-18 "Keep secrets out of the tree"
TL_SPECDIFF_CMD="$REPO/test/demo-specdiff.sh" TL_STANDARDS_CMD="$REPO/test/demo-standards.sh" \
  TL_DEMO_SEC_MODE=findings "$BIN/tl-review.sh" "$id" >/dev/null 2>&1
draft="$TL_DATA/$id/review-draft.md"
grep -q '## Security' "$draft" || fail "E: draft missing the Security section"
grep -q 'hardcoded credential' "$draft" || fail "E: draft missing the security finding"
[ -f "$TL_DATA/$id/standards-findings.tsv" ] || fail "E: standards axis did not run alongside"
# advisory holds: the standards axis ran, but no standards rule may ever reach gate findings
TL_DEMO_SEC_MODE=clean gate >/dev/null 2>&1 || fail "E: gate re-run failed"
jq -e '[.[]|select(.rule|startswith("standards-"))]|length==0' "$TL_DATA/$id/findings.json" >/dev/null \
  || fail "E: standards finding leaked into the gate (must stay advisory, #53 q2)"
echo "  E ok — three-axis draft; standards advisory, security gated"

echo "== F. unconfigured judge -> axis skipped =="
(unset TL_SECURITY_CMD; gate >/tmp/sec-f.log 2>&1) || fail "F: gate blocked with no security judge configured: $(cat /tmp/sec-f.log)"
echo "  F ok — bootstrap ceiling: no judge, no axis, gate unaffected"

echo "PASS: security axis blocks the gate (finding/crash/malformed), clean passes, standards stays advisory"
