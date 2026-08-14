#!/usr/bin/env bash
# infer-project-smoke.sh — tl-baseline / tl-scaffold-test / tl-scaffold-context default <project> to the
# sole project registered in the current .techlead (per-project state), like tl-kickoff. With zero or
# more-than-one registered, they refuse and ask for an explicit name. Token-free (demo scaffolders).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_LEAD="$WORK/lead" TL_WORKTREES="$WORK/state/wt"
export TL_SCAFFOLD_CONTEXT_CMD="$REPO/test/demo-scaffold-context.sh" TL_SCAFFOLD_TEST_CMD="$REPO/test/demo-scaffold-test.sh"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT
mkdir -p "$TL_DATA/projects"

PROJ="$(mktemp -d)"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
mkdir -p "$PROJ/.techlead/data"
printf '# Backlog\n\n## greet: print a greeting\nAdd hello() to greet.sh.\n' > "$PROJ/.techlead/data/backlog.md"
"$BIN/tl-project.sh" set app path "$PROJ"

echo "== I1: tl-scaffold-context with NO name arg resolves the sole project =="
"$BIN/tl-scaffold-context.sh" >/dev/null 2>/tmp/ip-i1.err || fail "I1: no-arg scaffold-context failed: $(cat /tmp/ip-i1.err)"
[ -f "$PROJ/AGENTS.md" ] && [ -f "$PROJ/CONTEXT.md" ] || fail "I1: did not draft the onboarding docs for the inferred project"
echo "  I1 ok"

echo "== I2: tl-scaffold-test with NO name arg resolves the sole project =="
"$BIN/tl-scaffold-test.sh" >/dev/null 2>/tmp/ip-i2.err || fail "I2: no-arg scaffold-test failed: $(cat /tmp/ip-i2.err)"
[ -f "$PROJ/test.sh" ] || fail "I2: did not draft test.sh for the inferred project"
echo "  I2 ok"

echo "== I3: tl-baseline with NO name arg resolves the sole project =="
"$BIN/tl-project.sh" set app test_command "sh test.sh"
"$BIN/tl-baseline.sh" >/dev/null 2>/tmp/ip-i3.err || fail "I3: no-arg baseline failed: $(cat /tmp/ip-i3.err)"
[ -n "$("$BIN/tl-project.sh" get app baseline 2>/dev/null)" ] || fail "I3: baseline not recorded for the inferred project"
echo "  I3 ok"

echo "== I4: two projects registered → no-arg refuses (ambiguous) =="
"$BIN/tl-project.sh" set other path "$PROJ"
if "$BIN/tl-baseline.sh" >/tmp/ip-i4.out 2>&1; then fail "I4: did not refuse with two projects"; fi
grep -q 'run from inside a project' /tmp/ip-i4.out || fail "I4: wrong refusal: $(cat /tmp/ip-i4.out)"
rm -f "$TL_DATA/projects/other.conf"
echo "  I4 ok"

echo "== I5: zero projects registered → no-arg refuses =="
rm -f "$TL_DATA/projects/app.conf"
if "$BIN/tl-scaffold-context.sh" >/tmp/ip-i5.out 2>&1; then fail "I5: did not refuse with zero projects"; fi
grep -q 'run from inside a project' /tmp/ip-i5.out || fail "I5: wrong refusal: $(cat /tmp/ip-i5.out)"
echo "  I5 ok"

echo "PASS: baseline / scaffold-test / scaffold-context infer the sole project; refuse when zero or ambiguous"
