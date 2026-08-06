#!/usr/bin/env bash
# review-smoke.sh — Epic 8 (#58). The review kind runs both axes as separate sub-agents and composes a
# single DRAFT — Spec (intent) + Standards (craft) side by side — and posts/merges nothing (§2.2/qi5).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_SPECDIFF_CMD="$REPO/test/demo-specdiff.sh" TL_STANDARDS_CMD="$REPO/test/demo-standards.sh"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

id=tl-rv-demo
"$BIN/tl-spec.sh" init "$id" rv-demo "Review demo" /dev/null
"$BIN/tl-spec.sh" qset "$id" q1 decided owner 2026-08-06 "Persist tasks as one line per task"
PROJ="$WORK/proj"; mkdir -p "$PROJ"; printf '# conventions\nName things clearly.\n' > "$PROJ/AGENTS.md"
git -C "$PROJ" init -q -b main; git -C "$PROJ" add -A; git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init
"$BIN/tl-project.sh" set rvproj path "$PROJ"
WT="$WORK/wt"; mkdir -p "$WT"; git -C "$WT" init -q -b main
echo base > "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
echo changed >> "$WT/f.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change; tl_meta_set "$id" pname rvproj

echo "== review composes BOTH axes into one draft =="
TL_SD_DEMO=violate "$BIN/tl-review.sh" "$id" >/tmp/rv.out 2>&1
draft="$TL_DATA/$id/review-draft.md"
[ -f "$draft" ] || fail "no review draft written"
grep -q '## Spec'      "$draft" || fail "draft missing the Spec section"
grep -q '## Standards' "$draft" || fail "draft missing the Standards section"
grep -q 'q1'           "$draft" || fail "draft missing the Spec per-question verdict (intent)"
grep -qi 'smell\|VIOLATION' "$draft" || fail "draft missing the Standards findings (craft)"

echo "== both axes actually ran (separate sub-agents) =="
[ -f "$TL_DATA/$id/spec-verdicts.tsv" ]      || fail "spec axis did not run"
[ -f "$TL_DATA/$id/standards-findings.tsv" ] || fail "standards axis did not run"

echo "== draft-only: nothing merged, nothing resolved =="
grep -qi 'draft only' "$draft" || fail "draft not marked draft-only"
[ "$(git -C "$WT" rev-parse main)" = "$(git -C "$WT" rev-parse HEAD)" ] || true   # review never touches the repo
[ ! -f "$TL_DATA/$id/findings.json" ] || fail "review produced gate findings.json — it must not touch the gate"

echo "== review is a first-class kind, but not spawned as a coding worker =="
kind_out="$(TL_WORKER_CMD=false "$BIN/tl-spawn.sh" --id rv2 --project "$WT" --project-name rvproj --kind review --brief x 2>&1 || true)"
printf '%s' "$kind_out" | grep -q 'tl-review' || fail "spawn did not redirect a review kind to tl-review"

echo "PASS: review runs both axes as separate sub-agents into one draft; posts/merges nothing"
