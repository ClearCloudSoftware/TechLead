#!/usr/bin/env bash
# change-smoke.sh — Epic 4. Proves the change lifecycle and every guard:
#   A. a clean change passes the gate and fast-forward-merges (E4.2/E4.5)
#   B. a test regression vs the baseline blocks delivery (E4.1/E4.2)
#   C. scope-cap + danger-path are flagged as findings (E4.3/E4.6)
#   D. the self-edit tangle guard catches a worker branch on the primary checkout (E4.4)
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }

# --- a project whose test command prints failing-test ids; flaky-1 is known-failing, and it
#     additionally fails reg-1 whenever a file named break.txt exists in the tree ---
PROJ="$(mktemp -d)"; git -C "$PROJ" init -q -b main
mkdir -p "$PROJ/tools"
cat > "$PROJ/tools/failing.sh" <<'SH'
#!/bin/sh
echo flaky-1
[ -f break.txt ] && echo reg-1
exit 0
SH
chmod +x "$PROJ/tools/failing.sh"
git -C "$PROJ" add -A && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init

WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_WORKER_CMD="$REPO/test/change-worker.sh"
cleanup() { rm -rf "$PROJ" "$WORK"; }; trap cleanup EXIT

echo "== register project + capture baseline =="
"$BIN/tl-project.sh" set proj path "$PROJ"
"$BIN/tl-project.sh" set proj mode local-only
"$BIN/tl-project.sh" set proj default_branch main
"$BIN/tl-project.sh" set proj readiness ready
"$BIN/tl-project.sh" set proj test_command "sh tools/failing.sh"
"$BIN/tl-project.sh" set proj danger_paths "secret/**"
"$BIN/tl-project.sh" set proj max_files_changed 3
"$BIN/tl-baseline.sh" proj
grep -qx flaky-1 "$WORK/data/projects/proj.baseline" || fail "baseline did not capture flaky-1"

sp() { TL_WORKER_CMD="$REPO/test/change-worker.sh" "$BIN/tl-spawn.sh" --project "$PROJ" --project-name proj --kind change "$@"; }
waitrep() { i=0; while [ $i -lt 20 ]; do [ -s "$WORK/data/$1/report.md" ] && return 0; sleep 1; i=$((i+1)); done; fail "$1 produced no report"; }

echo "== A. clean change -> gate -> ff-merge =="
TL_CW_FILES="hello.txt" sp --id ch-ok --brief "clean"
waitrep ch-ok
TL_APPROVE=yes "$BIN/tl-deliver.sh" ch-ok
git -C "$PROJ" cat-file -e main:hello.txt 2>/dev/null || fail "A: change did not land on main"
[ "$(git -C "$PROJ" rev-parse --abbrev-ref HEAD)" = main ] || fail "A: primary not on main after merge"
echo "  A ok — hello.txt on main"

echo "== B. regression blocks delivery =="
TL_CW_FILES="break.txt" sp --id ch-reg --brief "introduces a regression"
waitrep ch-reg
if TL_APPROVE=yes TL_RESOLVE=fix "$BIN/tl-deliver.sh" ch-reg >/tmp/chreg.log 2>&1; then fail "B: delivery succeeded despite a regression"; fi
grep -q 'gate blocked' /tmp/chreg.log || fail "B: expected a gate block, got: $(cat /tmp/chreg.log)"
git -C "$PROJ" cat-file -e main:break.txt 2>/dev/null && fail "B: regression change reached main" || true
jq -e '.[]|select(.rule=="test-regression")' "$WORK/data/ch-reg/findings.json" >/dev/null || fail "B: no test-regression finding"
echo "  B ok — regression flagged and blocked"

echo "== C. scope-cap + danger-path flagged =="
TL_CW_FILES="secret/key.txt a.txt b.txt c.txt d.txt" sp --id ch-dz --brief "5 files incl danger"
waitrep ch-dz
# fail closed: headless (no tty) with no TL_APPROVE must BLOCK, never silently auto-approve (§2.3.1)
if "$BIN/tl-gate.sh" ch-dz >/tmp/chfc.log 2>&1; then fail "C: gate passed headless without TL_APPROVE"; fi
grep -q 'gate blocked' /tmp/chfc.log || fail "C: expected a fail-closed block, got: $(cat /tmp/chfc.log)"
jq -e '[.[]|select(.resolved==null)]|length>0' "$WORK/data/ch-dz/findings.json" >/dev/null \
  || fail "C: findings were resolved without a human (fail-closed violation)"
TL_APPROVE=yes TL_RESOLVE=approve "$BIN/tl-gate.sh" ch-dz >/dev/null 2>&1 || true
jq -e '.[]|select(.rule=="scope-cap-exceeded")' "$WORK/data/ch-dz/findings.json" >/dev/null || fail "C: no scope finding"
jq -e '.[]|select(.rule=="danger-path")'       "$WORK/data/ch-dz/findings.json" >/dev/null || fail "C: no danger finding"
# #55/#56: every finding carries class_source; empty rubric -> ask-user/default:no-entry, and the
# danger-path finding carries its file in `path`
jq -e 'all(.[]; .class_source=="default:no-entry" and .class=="ask-user" and has("path") and has("line"))' \
  "$WORK/data/ch-dz/findings.json" >/dev/null || fail "C: findings missing class_source/path/line or not fail-closed"
jq -e '.[]|select(.rule=="danger-path")|.path|test("secret/")' "$WORK/data/ch-dz/findings.json" >/dev/null \
  || fail "C: danger-path finding did not record its file path"
# D13 (E1.5): resolving gate findings is the change-kind approval — its time must be recorded
awk -F'\t' '$2=="ch-dz" && $3=="approve"{f=1} END{exit f?0:1}' "$WORK/data/metrics.tsv" \
  || fail "C: gate did not record approve-time after resolving findings"
echo "  C ok — scope + danger both flagged as ask-user; approve-time recorded"

echo "== D. self-edit tangle guard =="
git -C "$PROJ" checkout -q -b tl/leak
if "$BIN/tl-guard-selfedit.sh" "$PROJ" >/dev/null 2>&1; then fail "D: guard missed a worker branch on primary"; fi
git -C "$PROJ" checkout -q main
echo "  D ok — guard caught tl/leak on the primary checkout"

echo "PASS: change lands via ff-merge; regression blocks; scope+danger flagged; self-edit guard trips"
