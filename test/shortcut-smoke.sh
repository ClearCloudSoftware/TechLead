#!/usr/bin/env bash
# shortcut-smoke.sh — Epic 8 (#57). The tl: annotated-shortcut detector: a tl: on a danger path is an
# ask-user finding (qi5); a tl: with no upgrade path is malformed; a well-formed tl: on a safe path is
# accepted silently. Findings route through the classifier and block until resolved.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
. "$BIN/tl-common.sh"
trap 'rm -rf "$WORK"' EXIT

id=tl-sc-demo
"$BIN/tl-project.sh" set scproj danger_paths "secret/**"
WT="$WORK/wt"; mkdir -p "$WT/secret"; git -C "$WT" init -q -b main
echo base > "$WT/app.txt"; git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m base
base="$(git -C "$WT" rev-parse HEAD)"
# added lines: a well-formed tl: (safe), a malformed tl: (safe), and a tl: on a danger path
printf 'x=1  # tl: linear scan — switch to a set if lists grow\n' >> "$WT/app.txt"
printf 'y=2  # tl: quick hack\n' >> "$WT/app.txt"
printf 'k=3  # tl: hardcoded key for now — read from vault once wired\n' > "$WT/secret/keys.txt"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m change
tl_meta_set "$id" worktree "$WT"; tl_meta_set "$id" base "$base"; tl_meta_set "$id" kind change; tl_meta_set "$id" pname scproj

# run from a CWD that CONTAINS a matching secret/ dir — regression guard for the danger-glob
# pathname-expansion bug (without set -f, `for g in $danger` would expand secret/** to real files)
cd "$WT"
out="$("$BIN/tl-shortcut.sh" "$id")"
echo "== a tl: shortcut on a danger path is flagged (qi5) =="
printf '%s' "$out" | grep -q '^tl-shortcut-danger' || fail "danger-path tl: not flagged"
printf '%s' "$out" | grep 'tl-shortcut-danger' | grep -q 'secret/keys.txt' || fail "danger finding not tied to the file"
echo "== a tl: with no upgrade path is malformed =="
printf '%s' "$out" | grep '^tl-shortcut-malformed' | grep -q 'quick hack' || fail "bare 'quick hack' tl: not flagged malformed"
echo "== a well-formed tl: on a safe path is accepted silently =="
printf '%s' "$out" | grep 'tl-shortcut-malformed' | grep -q 'linear scan' && fail "well-formed tl: wrongly flagged malformed" || true
printf '%s' "$out" | grep 'app.txt' | grep -q 'linear scan' && fail "safe well-formed tl: produced a finding" || true

echo "PASS: tl: shortcut detector — danger-path ask-user, malformed flagged, well-formed accepted"
