#!/usr/bin/env bash
# tl-security.sh — the Security review axis. Unlike Standards (draft-only, q2/#53), this axis BLOCKS:
# the delivery gate folds its findings into findings.json exactly like the Spec axis (#54 q5 pattern —
# "two homes": blocking at the gate, rendered draft-side by the review kind). Owner decision 2026-08-18:
# security blocks, code/standards stays advisory — a vulnerability is worth stopping a merge for.
# Two rule-ids: security-vulnerability (the judge found one) and security-unrunnable (the judge crashed
# or emitted nothing usable — fail closed, §3.9: a reviewer that dies must block, never silently pass).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
ff_path() { printf '%s/%s/security-findings.tsv' "$TL_DATA" "$1"; }

case "${1:?usage: tl-security run|findings|report ID}" in
  run)
    id="${2:?}"; wt="$(tl_meta_get "$id" worktree)"; base="$(tl_meta_get "$id" base)"
    : "${TL_SECURITY_CMD:?tl: no Security reviewer — set TL_SECURITY_CMD (e.g. adapters/claude-security.sh)}"
    diff="$(mktemp)"; git -C "$wt" --no-pager diff "$base"..HEAD > "$diff" 2>/dev/null || true
    ff="$(ff_path "$id")"; mkdir -p "$(dirname "$ff")"
    raw="$(mktemp)"; rc=0
    TL_SEC_ID="$id" TL_SEC_DIFF="$diff" $TL_SECURITY_CMD > "$raw" || rc=$?
    # the adapter filters its own output to well-formed lines; anything else here is a broken judge.
    awk -F'\t' 'NF>=3 && $1=="security-vulnerability"' "$raw" > "$ff"
    # fail closed: this axis gates the merge, so "the judge did not run" must surface as a finding —
    # non-zero exit, or output that was all malformed (raw non-empty but nothing survived the filter).
    if [ "$rc" -ne 0 ] || { [ -s "$raw" ] && [ ! -s "$ff" ]; }; then
      printf 'security-unrunnable\tsecurity judge exited %s with unusable output — review did not complete\t\n' "$rc" >> "$ff"
    fi
    rm -f "$diff" "$raw"
    echo "tl: security axis — $(grep -c . "$ff" || true) finding(s) (blocking at the gate)" >&2
    ;;
  findings)  # emit rule<TAB>detail<TAB>path for the gate fold (classified there, #55)
    id="${2:?}"; ff="$(ff_path "$id")"; [ -f "$ff" ] && cat "$ff" || true
    ;;
  report)  # human draft section — review kind (§2.2)
    id="${2:?}"; ff="$(ff_path "$id")"; [ -f "$ff" ] || { echo "no security findings for $id (run tl-security run $id)"; exit 0; }
    [ -s "$ff" ] || { echo "Security: clean — no findings"; exit 0; }
    awk -F'\t' '{printf "[SECURITY] %s  (%s)\n",$2,($3==""?"—":$3)}' "$ff"
    ;;
  *) tl_die "usage: tl-security run|findings|report ID";;
esac
