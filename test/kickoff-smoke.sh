#!/usr/bin/env bash
# kickoff-smoke.sh — tl-kickoff runs a terminal interview via transcript replay: the driver asks until
# it has enough, then emits CONTEXT + BACKLOG; the loop persists CONTEXT.md (uncommitted, no overwrite),
# prints ready tl-backlog add lines, and is killable/resumable via the transcript file. Token-free
# (demo-kickoff; owner answers piped on stdin).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK" "$PROJ" 2>/dev/null; }; trap cleanup EXIT
DEMO="$REPO/test/demo-kickoff.sh"

newproj() {  # fresh registered project each case
  PROJ="$(mktemp -d)/app"; mkdir -p "$PROJ/.techlead/data"
  git -C "$PROJ" init -q -b main
  git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  export TL_HOME="$REPO" TL_DATA="$PROJ/.techlead/data" TL_STATE="$PROJ/.techlead/state" TL_LEAD="$PROJ/.techlead/lead"
  mkdir -p "$TL_STATE"
  "$BIN/tl-project.sh" set app path "$PROJ"
}

echo "== K1: a full interview writes CONTEXT.md (uncommitted) + prints seed-backlog lines; transcript cleared =="
newproj
printf 'a widget thing\nit stores and lists widgets\n' | TL_KICKOFF_CMD="$DEMO" "$BIN/tl-kickoff.sh" app >/tmp/kf-k1.out 2>/tmp/kf-k1.err || fail "K1: errored: $(cat /tmp/kf-k1.err)"
[ -f "$PROJ/CONTEXT.md" ] || fail "K1: no CONTEXT.md written"
grep -q 'widget' "$PROJ/CONTEXT.md" || fail "K1: CONTEXT.md missing the glossary term"
[ -n "$(git -C "$PROJ" status --porcelain CONTEXT.md 2>/dev/null)" ] || fail "K1: CONTEXT.md was committed (must stay for review)"
grep -q 'tl-backlog add add-widget' /tmp/kf-k1.err || fail "K1: did not print the seed-backlog add lines: $(cat /tmp/kf-k1.err)"
[ ! -f "$TL_DATA/kickoff-app.transcript" ] || fail "K1: transcript not cleared on success"
echo "  K1 ok — interview → CONTEXT.md + backlog lines, transcript cleared"

echo "== K2: refuses when CONTEXT.md already exists (before any interview) =="
newproj; printf '# CONTEXT.md\nexisting\n' > "$PROJ/CONTEXT.md"
if printf 'x\ny\n' | TL_KICKOFF_CMD="$DEMO" "$BIN/tl-kickoff.sh" app >/tmp/kf-k2.out 2>&1; then fail "K2: did not refuse an existing CONTEXT.md"; fi
grep -q 'already exists' /tmp/kf-k2.out || fail "K2: wrong refusal: $(cat /tmp/kf-k2.out)"
echo "  K2 ok — existing CONTEXT.md preserved"

echo "== K3: a missing/unexecutable driver → refuses (before any prompt) =="
newproj
if TL_KICKOFF_CMD="$WORK/no-such-driver" "$BIN/tl-kickoff.sh" app </dev/null >/tmp/kf-k3.out 2>&1; then fail "K3: did not refuse a missing driver"; fi
grep -q 'no kickoff driver' /tmp/kf-k3.out || fail "K3: wrong error: $(cat /tmp/kf-k3.out)"
[ ! -e "$PROJ/CONTEXT.md" ] || fail "K3: wrote CONTEXT.md despite no driver"
echo "  K3 ok"

echo "== K4: <project> optional — inferred from the current .techlead =="
newproj
printf 'w\nx\n' | TL_KICKOFF_CMD="$DEMO" "$BIN/tl-kickoff.sh" >/tmp/kf-k4.out 2>/tmp/kf-k4.err || fail "K4: no-arg kickoff failed: $(cat /tmp/kf-k4.err)"
[ -f "$PROJ/CONTEXT.md" ] || fail "K4: did not resolve the current project"
echo "  K4 ok — inferred the project"

echo "== K5: interrupted (owner pauses) keeps the transcript and writes nothing (resumable) =="
newproj
printf 'only one answer\n' | TL_KICKOFF_CMD="$DEMO" "$BIN/tl-kickoff.sh" app >/tmp/kf-k5.out 2>/tmp/kf-k5.err || fail "K5: errored on pause"
[ -f "$TL_DATA/kickoff-app.transcript" ] || fail "K5: transcript not kept for resume"
[ ! -e "$PROJ/CONTEXT.md" ] || fail "K5: wrote CONTEXT.md from an unfinished interview"
grep -q 'paused' /tmp/kf-k5.err || fail "K5: did not report the pause"
echo "  K5 ok — paused, transcript kept, nothing written"

echo "PASS: tl-kickoff interviews via transcript replay; persists CONTEXT.md draft + backlog lines; killable/resumable; no overwrite"
