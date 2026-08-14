#!/usr/bin/env bash
# scaffold-test-smoke.sh — tl-scaffold-test drafts a test harness for a survey project from its backlog,
# sets test_command, and STOPS (draft-then-approve): it must NOT baseline or promote (what "done" means
# is the owner's), must NOT overwrite an existing test.sh, and must refuse cleanly with no scaffolder.
# Token-free (demo-scaffold-test).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT

# a greenfield survey project with a backlog behaviour, registered in its own .techlead
PROJ="$(mktemp -d)/app"; mkdir -p "$PROJ/.techlead/data"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
cat > "$PROJ/.techlead/data/backlog.md" <<'EOF'
# Backlog

## greet: print a greeting
Add hello() to greet.sh that echoes "hi".
EOF
export TL_HOME="$REPO" TL_DATA="$PROJ/.techlead/data" TL_STATE="$PROJ/.techlead/state" TL_LEAD="$PROJ/.techlead/lead"
mkdir -p "$TL_STATE" "$TL_LEAD"
"$BIN/tl-project.sh" set app path "$PROJ"
"$BIN/tl-project.sh" set app readiness survey

echo "== S1: no scaffolder configured → refuses with a by-hand hint, writes nothing =="
if TL_SCAFFOLD_TEST_CMD= "$BIN/tl-scaffold-test.sh" app >/tmp/st-s1.log 2>&1; then fail "S1: did not refuse without a scaffolder"; fi
grep -q "no scaffolder configured" /tmp/st-s1.log || fail "S1: wrong refusal: $(cat /tmp/st-s1.log)"
[ ! -e "$PROJ/test.sh" ] || fail "S1: wrote test.sh despite no scaffolder"
echo "  S1 ok — refused cleanly, no file written"

echo "== S2: drafts test.sh + sets test_command, but does NOT baseline/promote =="
TL_SCAFFOLD_TEST_CMD="$REPO/test/demo-scaffold-test.sh" "$BIN/tl-scaffold-test.sh" app >/tmp/st-s2.log 2>&1 || fail "S2: errored: $(cat /tmp/st-s2.log)"
[ -f "$PROJ/test.sh" ] || fail "S2: no test.sh drafted"
[ -x "$PROJ/test.sh" ] || fail "S2: test.sh not executable"
head -1 "$PROJ/test.sh" | grep -q '^#!/bin/sh' || fail "S2: drafted harness missing shebang"
grep -q 'greet-hi' "$PROJ/test.sh" || fail "S2: drafted harness missing the failing-id"
[ "$("$BIN/tl-project.sh" get app test_command)" = "sh test.sh" ] || fail "S2: test_command not set"
[ "$("$BIN/tl-project.sh" get app readiness)" = survey ] || fail "S2: promoted readiness (must stay survey until owner baselines)"
[ -z "$("$BIN/tl-project.sh" get app baseline 2>/dev/null)" ] || fail "S2: captured a baseline (must be owner's step)"
grep -q "REVIEW it" /tmp/st-s2.log || fail "S2: did not stop for owner review"
echo "  S2 ok — drafted + test_command set; no baseline, still survey, stopped for review"

echo "== S3: the drafted harness is a valid failing-id contract (fails before, passes after) =="
( cd "$PROJ" && out_before="$(sh test.sh 2>/dev/null)"; [ "$out_before" = greet-hi ] || exit 3 ) || fail "S3: harness did not emit greet-hi with no app"
printf '#!/usr/bin/env bash\nhello(){ echo hi; }\nhello\n' > "$PROJ/greet.sh"
( cd "$PROJ" && [ -z "$(sh test.sh 2>/dev/null)" ] ) || fail "S3: harness still failed after the behaviour was built"
echo "  S3 ok — emits greet-hi unbuilt, silent once greet.sh prints hi"

echo "== S4: refuses to overwrite an existing test.sh =="
if TL_SCAFFOLD_TEST_CMD="$REPO/test/demo-scaffold-test.sh" "$BIN/tl-scaffold-test.sh" app >/tmp/st-s4.log 2>&1; then fail "S4: overwrote an existing test.sh"; fi
grep -q "already exists" /tmp/st-s4.log || fail "S4: wrong refusal: $(cat /tmp/st-s4.log)"
echo "  S4 ok — existing harness preserved"

echo "PASS: tl-scaffold-test drafts a valid harness + sets test_command, leaves baseline/promote to the owner, and won't overwrite"
