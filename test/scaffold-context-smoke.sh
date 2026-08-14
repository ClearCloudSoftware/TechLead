#!/usr/bin/env bash
# scaffold-context-smoke.sh — tl-scaffold-context drafts a project's AGENTS.md + CONTEXT.md as real
# files (draft-then-approve: never commits, never overwrites), and once committed the grill reads them
# (#60). Token-free (demo scaffolder + a context-reporting demo grill).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT

# a registered project in its own .techlead, no context docs yet
PROJ="$(mktemp -d)/app"; mkdir -p "$PROJ/.techlead/data" "$PROJ/.techlead/lead"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
export TL_HOME="$REPO" TL_DATA="$PROJ/.techlead/data" TL_STATE="$PROJ/.techlead/state" TL_LEAD="$PROJ/.techlead/lead"
export TL_BACKLOG="$PROJ/.techlead/data/backlog.md"
mkdir -p "$TL_STATE"
"$BIN/tl-project.sh" set app path "$PROJ"

echo "== C1: no scaffolder → refuses with a by-hand hint, writes nothing =="
if TL_SCAFFOLD_CONTEXT_CMD= "$BIN/tl-scaffold-context.sh" app >/tmp/sc-c1.log 2>&1; then fail "C1: did not refuse without a scaffolder"; fi
grep -q 'no scaffolder configured' /tmp/sc-c1.log || fail "C1: wrong refusal: $(cat /tmp/sc-c1.log)"
[ ! -e "$PROJ/AGENTS.md" ] && [ ! -e "$PROJ/CONTEXT.md" ] || fail "C1: wrote docs despite no scaffolder"
echo "  C1 ok"

echo "== C2: drafts both docs as real files, does NOT commit =="
TL_SCAFFOLD_CONTEXT_CMD="$REPO/test/demo-scaffold-context.sh" "$BIN/tl-scaffold-context.sh" app >/tmp/sc-c2.log 2>&1 || fail "C2: errored: $(cat /tmp/sc-c2.log)"
[ -f "$PROJ/AGENTS.md" ] || fail "C2: no AGENTS.md drafted"
[ -f "$PROJ/CONTEXT.md" ] || fail "C2: no CONTEXT.md drafted"
grep -q 'Danger zones' "$PROJ/AGENTS.md" || fail "C2: AGENTS.md missing expected section"
grep -q 'Glossary' "$PROJ/CONTEXT.md" || fail "C2: CONTEXT.md missing glossary"
[ -n "$(git -C "$PROJ" status --porcelain 2>/dev/null)" ] || fail "C2: docs were committed (must stay for owner review)"
grep -q 'REVIEW them' /tmp/sc-c2.log || fail "C2: did not stop for owner review"
echo "  C2 ok — both drafted, uncommitted, stopped for review"

echo "== C3: refuses to overwrite an existing doc (drafts only what's missing) =="
rm -f "$PROJ/CONTEXT.md"   # AGENTS.md stays, CONTEXT.md missing again
TL_SCAFFOLD_CONTEXT_CMD="$REPO/test/demo-scaffold-context.sh" "$BIN/tl-scaffold-context.sh" app >/tmp/sc-c3.log 2>&1 || fail "C3: errored"
grep -q 'skip AGENTS.md' /tmp/sc-c3.log || fail "C3: did not skip the existing AGENTS.md"
[ -f "$PROJ/CONTEXT.md" ] || fail "C3: did not draft the missing CONTEXT.md"
echo "  C3 ok — existing doc preserved, missing one drafted"

echo "== C4: once committed, a grill reads the project context (AGENTS.md + CONTEXT.md) =="
git -C "$PROJ" add -A && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m "onboarding docs"
printf '# Backlog\n\n## feat-x: do a thing\nTouch the widget.\n' > "$TL_BACKLOG"
( cd "$PROJ" && TL_GRILL_CMD="$REPO/test/demo-grill-ctx.sh" "$BIN/tl-grill.sh" feat-x >/dev/null 2>&1 )
"$BIN/tl-spec.sh" qlist tl-feat-x | grep -q 'CTX-SEEN' || fail "C4: grill did not receive the project context (got: $("$BIN/tl-spec.sh" qlist tl-feat-x))"
echo "  C4 ok — grill saw the committed AGENTS.md/CONTEXT.md"

echo "PASS: tl-scaffold-context drafts real onboarding docs (draft-then-approve, no overwrite); the grill reads them once committed"
