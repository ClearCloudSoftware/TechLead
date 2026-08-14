#!/usr/bin/env bash
# spec-diff-smoke.sh — Epic 8 (#54). The Spec axis is marker-driven (only `decided` questions can be
# violated), shows its work, treats can't-evaluate as loud as a violation, and folds violations into the
# delivery gate as blocking ask-user findings (q1/q3/q5).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_SPECDIFF_CMD="$REPO/test/demo-specdiff.sh"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

id=tl-sd-demo
"$BIN/tl-spec.sh" init "$id" sd-demo "Spec-diff demo" /dev/null
"$BIN/tl-spec.sh" qset "$id" q1 decided owner 2026-08-05 "Persist tasks as one line per task"
"$BIN/tl-spec.sh" qset "$id" q2 leaning owner 2026-08-05 "Might use JSON later"   # leaning: never a violation

WT="$WORK/wt"; mkdir -p "$WT"; git -C "$WT" init -q -b main
echo base > "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
echo changed >> "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change

echo "== clean: the 1 decided question is checked (leaning excluded), no findings =="
TL_SD_DEMO=clean "$BIN/tl-specdiff.sh" run "$id" 2>/tmp/sd.rep
grep -q '1 of 1 decided' /tmp/sd.rep || fail "clean: did not check exactly the 1 decided question"
[ -z "$("$BIN/tl-specdiff.sh" findings "$id")" ] || fail "clean: emitted findings when satisfied"

echo "== violate: decided contradiction -> loud spec-violation finding tied to its qid =="
TL_SD_DEMO=violate "$BIN/tl-specdiff.sh" run "$id" 2>/dev/null
f="$("$BIN/tl-specdiff.sh" findings "$id")"
printf '%s' "$f" | grep -q '^spec-violation' || fail "violate: no spec-violation finding"
printf '%s' "$f" | grep -q 'q1'              || fail "violate: finding not tied to the qid (shows work)"

echo "== uncheckable is as loud as a violation =="
TL_SD_DEMO=uncheckable "$BIN/tl-specdiff.sh" run "$id" 2>/dev/null
"$BIN/tl-specdiff.sh" findings "$id" | grep -q '^spec-uncheckable' || fail "uncheckable: not surfaced"

echo "== gate integration: a decided violation blocks delivery as an ask-user finding (q5 + #55) =="
"$BIN/tl-project.sh" set sdproj path "$WT"
"$BIN/tl-project.sh" set sdproj test_command "true"          # no test regressions -> spec is the only finding
"$BIN/tl-project.sh" set sdproj default_branch main
tl_meta_set "$id" pname sdproj
if TL_SD_DEMO=violate "$BIN/tl-gate.sh" "$id" >/tmp/sd.gate 2>&1; then fail "gate: passed despite a spec violation"; fi
grep -q 'gate blocked' /tmp/sd.gate || fail "gate: did not block on the spec violation"
jq -e '.[]|select(.rule=="spec-violation" and .class=="ask-user")' "$TL_DATA/$id/findings.json" >/dev/null \
  || fail "gate: spec-violation not folded in as an ask-user finding"

echo "PASS: spec axis marker-driven (leaning ignored), shows work, violations+uncheckables loud, gate blocks"
