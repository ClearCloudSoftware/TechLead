#!/usr/bin/env bash
# run-smoke.sh — tl-spawn argument consolidation + the tl-run driver. Deterministic and token-free
# (demo-grill + change-worker; no live model). Proves:
#   Part A — tl-spawn <id> resolves brief/project/kind from state; explicit flags/spec fields win;
#            each unresolvable case refuses with the specific missing piece named.
#   Part B — tl-run walks grill→brief→spawn→gate/deliver, STOPS at the two owner-judgment points
#            (spec approval/reject, gate findings), hands off after spawn, and is resumable.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_GRILL_CMD="$REPO/test/demo-grill.sh" TL_WORKER_CMD="$REPO/test/change-worker.sh"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT
mkdir -p "$TL_DATA/projects"
kmeta() { awk -F= -v k="$2" '$1==k{print $2}' "$TL_STATE/$1.meta"; }
# wait for the worker to actually finish: tl-state reconciles from process liveness (§3.4), so the
# report can exist a beat before the state flips to done — poll the authoritative state, not the file.
waitdone() { i=0; while [ $i -lt 40 ]; do s="$("$BIN/tl-state.sh" "$1" 2>/dev/null || echo '?')"; case "$s" in done) return 0;; failed) fail "$1: worker failed";; esac; sleep 1; i=$((i+1)); done; fail "$1: worker not done (state=$s)"; }

# a registered project (readiness=ready → kind resolves to change). Its test prints a stable failing
# id plus reg-1 whenever break.txt exists — a regression trigger.
PROJ="$(mktemp -d)"; mkdir -p "$PROJ/tools"
cat > "$PROJ/tools/failing.sh" <<'SH'
#!/bin/sh
echo flaky-1
[ -f break.txt ] && echo reg-1
exit 0
SH
chmod +x "$PROJ/tools/failing.sh"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init
"$BIN/tl-project.sh" set todo path "$PROJ"
"$BIN/tl-project.sh" set todo mode local-only
"$BIN/tl-project.sh" set todo default_branch main
"$BIN/tl-project.sh" set todo readiness ready
"$BIN/tl-project.sh" set todo test_command "sh tools/failing.sh"   # keep as ONE value — has a space
"$BIN/tl-project.sh" set todo max_files_changed 5
"$BIN/tl-baseline.sh" todo >/dev/null
grep -qx flaky-1 "$TL_DATA/projects/todo.baseline" || fail "setup: baseline did not capture flaky-1 (test_command not set correctly?)"

echo "===== Part A — tl-spawn resolution ====="

echo "== A1: tl-spawn <id> resolves brief+project+kind from state (no flags) =="
mkdir -p "$TL_DATA/tl-a1"; echo "brief a1" > "$TL_DATA/tl-a1/brief.md"
TL_CW_FILES="a1.txt" "$BIN/tl-spawn.sh" tl-a1
[ "$(kmeta tl-a1 kind)"  = change ] || fail "A1: kind not resolved to change (from readiness)"
[ "$(kmeta tl-a1 pname)" = todo ]   || fail "A1: pname not resolved to the sole registered project"
waitdone tl-a1
echo "  A1 ok — resolved kind=change, pname=todo, dispatched with no flags"

echo "== A2: a spec 'kind' field overrides the readiness default =="
"$BIN/tl-spec.sh" init tl-a2 a2 "A2" >/dev/null; "$BIN/tl-spec.sh" set tl-a2 kind plan
mkdir -p "$TL_DATA/tl-a2"; echo "brief a2" > "$TL_DATA/tl-a2/brief.md"
TL_CW_FILES="a2.txt" "$BIN/tl-spawn.sh" tl-a2
[ "$(kmeta tl-a2 kind)" = plan ] || fail "A2: spec kind=plan did not override readiness"
waitdone tl-a2
echo "  A2 ok — spec kind=plan won over readiness=ready"

echo "== A3: an explicit --kind flag overrides everything =="
mkdir -p "$TL_DATA/tl-a3"; echo b > "$TL_DATA/tl-a3/brief.md"
TL_CW_FILES="a3.txt" "$BIN/tl-spawn.sh" tl-a3 --kind plan
[ "$(kmeta tl-a3 kind)" = plan ] || fail "A3: --kind flag did not override"
waitdone tl-a3
echo "  A3 ok — explicit --kind wins"

echo "== A4: refuse (named) when kind is unresolvable (unregistered --project) =="
UNREG="$(mktemp -d)"
if "$BIN/tl-spawn.sh" tl-a4 --project "$UNREG" >/tmp/rs-a4.log 2>&1; then fail "A4: spawn did not refuse"; fi
grep -q "cannot resolve kind" /tmp/rs-a4.log || fail "A4: wrong refusal: $(cat /tmp/rs-a4.log)"
[ ! -f "$TL_STATE/tl-a4.meta" ] || fail "A4: dispatched despite refusal"
echo "  A4 ok — named refusal for kind, nothing dispatched"

echo "== A5: refuse (named) when the project is ambiguous (2 registered, none chosen) =="
"$BIN/tl-project.sh" set other path "$UNREG"; "$BIN/tl-project.sh" set other readiness ready
mkdir -p "$TL_DATA/tl-a5"; echo b > "$TL_DATA/tl-a5/brief.md"
if "$BIN/tl-spawn.sh" tl-a5 >/tmp/rs-a5.log 2>&1; then fail "A5: spawn did not refuse on ambiguous project"; fi
grep -q "cannot resolve project" /tmp/rs-a5.log || fail "A5: wrong refusal: $(cat /tmp/rs-a5.log)"
rm -f "$TL_DATA/projects/other.conf"   # restore the sole project for Part B
rmdir "$UNREG" 2>/dev/null || true
echo "  A5 ok — named refusal for an ambiguous project"

echo "== A6: full-flag form is still accepted (back-compat) =="
mkdir -p "$TL_DATA/tl-a6"
TL_CW_FILES="a6.txt" "$BIN/tl-spawn.sh" --id tl-a6 --project "$PROJ" --project-name todo --kind change --brief "manual brief string"
[ "$(kmeta tl-a6 kind)" = change ] && [ "$(kmeta tl-a6 pname)" = todo ] || fail "A6: explicit flag form broke"
waitdone tl-a6
echo "  A6 ok — explicit flags unchanged"

echo "===== Part B — tl-run driver ====="
cat > "$TL_DATA/backlog.md" <<'EOF'
# Backlog

## add-list: Add and list todos
Persist tasks; list with a 1-based index.

## risky: A change that regresses a test

## bad-idea: Rewrite it in assembly for speed

## resume-me: An item whose first grill was interrupted

## empty-bank: An item grilled against an empty question bank
EOF

echo "== B1: tl-run STOPS at an open spec, dispatching nothing =="
"$BIN/tl-run.sh" add-list >/tmp/rs-b1.log 2>&1 || true
grep -q "STOP" /tmp/rs-b1.log || fail "B1: tl-run did not stop at the open spec"
[ "$("$BIN/tl-spec.sh" get tl-add-list state)" = drafted ] || fail "B1: spec not drafted"
[ ! -f "$TL_STATE/tl-add-list.meta" ] || fail "B1: dispatched despite an open question"
echo "  B1 ok — halted at the spec stop, nothing dispatched"

echo "== B2: answer the open → tl-run resumes → brief → spawn (supervised, non-blocking) =="
"$BIN/tl-grill.sh" answer tl-add-list q2 decided "1-based; one task per line" >/dev/null
TL_CW_FILES="feat.txt" "$BIN/tl-run.sh" add-list >/tmp/rs-b2.log 2>&1 || fail "B2: tl-run errored: $(cat /tmp/rs-b2.log)"
[ -f "$TL_DATA/tl-add-list/brief.md" ] || fail "B2: no brief produced"
[ -f "$TL_STATE/tl-add-list.meta" ] || fail "B2: task not spawned"
[ "$(kmeta tl-add-list kind)" = change ] || fail "B2: kind not resolved to change"
grep -q "supervised" /tmp/rs-b2.log || fail "B2: did not hand off to tl-watch (blocked instead?)"
echo "  B2 ok — resumed, briefed, dispatched, returned without babysitting"

echo "== B2b: re-run mid-flight is idempotent (recomputes stage, does not re-spawn) =="
base="$(kmeta tl-add-list base)"
"$BIN/tl-run.sh" add-list >/tmp/rs-b2b.log 2>&1 || true
grep -Eq "still working|gate|deliver|delivered" /tmp/rs-b2b.log || fail "B2b: unexpected output: $(cat /tmp/rs-b2b.log)"
[ "$(kmeta tl-add-list base)" = "$base" ] || fail "B2b: re-invocation re-spawned the task (base changed)"
echo "  B2b ok — re-invocation recomputed the stage, no second dispatch"

waitdone tl-add-list

echo "== B3: worker done → tl-run resumes at the gate → clean change delivers =="
TL_APPROVE=yes TL_RESOLVE=approve "$BIN/tl-run.sh" add-list >/tmp/rs-b3.log 2>&1 || fail "B3: deliver failed: $(cat /tmp/rs-b3.log)"
grep -q "delivered" /tmp/rs-b3.log || fail "B3: not delivered"
git -C "$PROJ" cat-file -e main:feat.txt 2>/dev/null || fail "B3: clean change did not land on main"
echo "  B3 ok — resumed at the gate, clean change ff-merged"

echo "== B3b: re-run after delivery is idempotent =="
"$BIN/tl-run.sh" add-list >/tmp/rs-b3b.log 2>&1 || true
grep -q "already delivered" /tmp/rs-b3b.log || fail "B3b: not idempotent after delivery: $(cat /tmp/rs-b3b.log)"
echo "  B3b ok — already delivered"

echo "== B3c: teardown after a local-only (ff-merge) delivery needs no --force =="
"$BIN/tl-teardown.sh" tl-add-list >/tmp/rs-b3c.log 2>&1 \
  || fail "B3c: teardown refused a delivered ff-merge — the guard must key on 'delivered', not 'pr': $(cat /tmp/rs-b3c.log)"
echo "  B3c ok — an ff-merged (local-only) task tore down without --force"

echo "== B4: gate STOPS on unresolved findings; the regression never merges =="
"$BIN/tl-run.sh" risky >/dev/null 2>&1 || true                       # stop at open spec
"$BIN/tl-grill.sh" answer tl-risky q2 decided "ok" >/dev/null
TL_CW_FILES="break.txt" "$BIN/tl-run.sh" risky >/dev/null 2>&1 || fail "B4: spawn phase failed"
waitdone tl-risky
if TL_APPROVE=yes TL_RESOLVE=fix "$BIN/tl-run.sh" risky >/tmp/rs-b4.log 2>&1; then fail "B4: delivered despite a regression"; fi
grep -q "STOP" /tmp/rs-b4.log || fail "B4: no stop on unresolved findings: $(cat /tmp/rs-b4.log)"
git -C "$PROJ" cat-file -e main:break.txt 2>/dev/null && fail "B4: regression reached main" || true
echo "  B4 ok — halted at the gate; regression never merged"

echo "== B5: a rejected item halts and dispatches nothing =="
"$BIN/tl-run.sh" bad-idea >/dev/null 2>&1 || true                    # stop at open spec (creates it)
"$BIN/tl-grill.sh" reject tl-bad-idea "Premature — no perf problem exists" >/dev/null
"$BIN/tl-run.sh" bad-idea >/tmp/rs-b5.log 2>&1 || true
grep -q "rejected" /tmp/rs-b5.log || fail "B5: tl-run did not honor the reject: $(cat /tmp/rs-b5.log)"
[ ! -f "$TL_STATE/tl-bad-idea.meta" ] || fail "B5: dispatched a rejected item"
echo "  B5 ok — rejected item halts, nothing dispatched"

echo "== B6: an interrupted grill (spec exists but never finalized) self-heals on re-run =="
# Simulate a grill that died before _finalize (e.g. TL_GRILL_CMD was unset on the first run): the
# spec file exists, state=drafted, with zero questions. Old tl-run keyed on "file exists" and would
# skip the grill forever — wedged. Now it re-grills a drafted-with-0-open spec automatically.
"$BIN/tl-spec.sh" init tl-resume-me resume-me "An item whose first grill was interrupted" >/dev/null
[ "$("$BIN/tl-spec.sh" get tl-resume-me state)" = drafted ] || fail "B6 setup: spec should be drafted"
[ "$("$BIN/tl-spec.sh" open-count tl-resume-me)" -eq 0 ]     || fail "B6 setup: expected 0 open (grill not run yet)"
"$BIN/tl-run.sh" resume-me >/tmp/rs-b6.log 2>&1 || true
grep -q "grill" /tmp/rs-b6.log || fail "B6: tl-run did not re-grill the interrupted spec: $(cat /tmp/rs-b6.log)"
[ "$("$BIN/tl-spec.sh" qlist tl-resume-me | grep -c .)" -gt 0 ] || fail "B6: grill did not run (no questions added)"
[ "$("$BIN/tl-spec.sh" open-count tl-resume-me)" -gt 0 ] || fail "B6: expected the re-grill to surface the owner's open question"
[ ! -f "$TL_STATE/tl-resume-me.meta" ] || fail "B6: dispatched despite a fresh open question"
echo "  B6 ok — interrupted grill re-ran on tl-run; no longer wedged, halted at the new open question"

echo "== B7: an empty question bank (grill yields 0 questions) → tl-run REFUSES to dispatch (fail closed) =="
# Simulate an empty lead/questions.md by pointing the grill at a driver that emits nothing. The grill
# runs but produces 0 questions; tl-run must refuse rather than brief+spawn an un-grilled item.
TL_GRILL_CMD=/usr/bin/true "$BIN/tl-run.sh" empty-bank >/tmp/rs-b7.log 2>&1 || true
grep -q "no grilled questions" /tmp/rs-b7.log || fail "B7: tl-run did not refuse the un-grilled item: $(cat /tmp/rs-b7.log)"
[ ! -f "$TL_STATE/tl-empty-bank.meta" ]   || fail "B7: dispatched an un-grilled item"
[ ! -f "$TL_DATA/tl-empty-bank/brief.md" ] || fail "B7: briefed an un-grilled item"
echo "  B7 ok — 0-question grill refused at the chokepoint; nothing briefed or dispatched"

echo "PASS: tl-spawn resolves + refuses by name; tl-run stops at spec & gate, hands off, and is resumable"
