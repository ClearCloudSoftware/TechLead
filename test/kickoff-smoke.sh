#!/usr/bin/env bash
# kickoff-smoke.sh — tl-kickoff persists a composed CONTEXT.md for a greenfield project (draft-then-
# approve: uncommitted, no overwrite, refuses empty input). The interview is the skill's job (chat),
# not tested here. Token-free.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT

PROJ="$(mktemp -d)/app"; mkdir -p "$PROJ/.techlead/data"
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
export TL_HOME="$REPO" TL_DATA="$PROJ/.techlead/data" TL_STATE="$PROJ/.techlead/state" TL_LEAD="$PROJ/.techlead/lead"
mkdir -p "$TL_STATE" "$TL_LEAD"
"$BIN/tl-project.sh" set app path "$PROJ"

echo "== K1: writes the piped CONTEXT.md, uncommitted, and prints review/commit next-steps =="
printf '# CONTEXT.md\n\n## Glossary\n- **streak** — consecutive days a habit was met.\n' \
  | "$BIN/tl-kickoff.sh" app >/tmp/kf-k1.log 2>&1 || fail "K1: errored: $(cat /tmp/kf-k1.log)"
[ -f "$PROJ/CONTEXT.md" ] || fail "K1: CONTEXT.md not written"
grep -q 'streak' "$PROJ/CONTEXT.md" || fail "K1: piped content not written"
[ -n "$(git -C "$PROJ" status --porcelain CONTEXT.md 2>/dev/null)" ] || fail "K1: CONTEXT.md was committed (must stay for review)"
grep -q 'REVIEW it' /tmp/kf-k1.log || fail "K1: did not stop for owner review"
grep -q 'tl-backlog add' /tmp/kf-k1.log || fail "K1: did not point at seeding the backlog"
echo "  K1 ok — wrote uncommitted CONTEXT.md, stopped for review"

echo "== K2: refuses to overwrite an existing CONTEXT.md =="
if printf 'x\n' | "$BIN/tl-kickoff.sh" app >/tmp/kf-k2.log 2>&1; then fail "K2: overwrote an existing CONTEXT.md"; fi
grep -q 'already exists' /tmp/kf-k2.log || fail "K2: wrong refusal: $(cat /tmp/kf-k2.log)"
grep -q 'streak' "$PROJ/CONTEXT.md" || fail "K2: clobbered the existing CONTEXT.md"
echo "  K2 ok — existing CONTEXT.md preserved"

echo "== K3: refuses empty stdin (nothing to persist) =="
rm -f "$PROJ/CONTEXT.md"
if printf '' | "$BIN/tl-kickoff.sh" app >/tmp/kf-k3.log 2>&1; then fail "K3: accepted empty input"; fi
grep -q 'no CONTEXT.md content' /tmp/kf-k3.log || fail "K3: wrong error for empty input: $(cat /tmp/kf-k3.log)"
[ ! -e "$PROJ/CONTEXT.md" ] || fail "K3: wrote an empty CONTEXT.md"
echo "  K3 ok — empty input refused, nothing written"

echo "== K4: <project> is optional — defaults to the sole project registered here =="
rm -f "$PROJ/CONTEXT.md"
printf '# CONTEXT.md\n\n## Glossary\n- **streak** — days in a row.\n' | "$BIN/tl-kickoff.sh" >/tmp/kf-k4.log 2>&1 \
  || fail "K4: no-arg kickoff failed to resolve the current project: $(cat /tmp/kf-k4.log)"
[ -f "$PROJ/CONTEXT.md" ] || fail "K4: did not write CONTEXT.md when the name was inferred"
echo "  K4 ok — inferred the project from the current .techlead"

echo "PASS: tl-kickoff persists a composed CONTEXT.md (uncommitted, no overwrite, no empty write; infers the project)"
