#!/usr/bin/env bash
# tl-standards.sh — the Standards review axis (§2.2, D6, E8.1 / #53). BORROWED craft: runs the vendored
# mattpocock/code-review Standards brief against the repo's documented standards (AGENTS.md, canonical
# per §2.7 + lead/review-rubric.md). Draft-only (q2) — findings advise, never block — and it runs in the
# `review` kind ONLY (q5), never on the change gate. Two rule-ids (q6): standards-violation (hard, broke
# a documented rule) and standards-smell (Fowler baseline, always a judgement call). Its findings are a
# starting draft for lead/review-rubric.md, never a substitute (§3.14).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
ff_path() { printf '%s/%s/standards-findings.tsv' "$TL_DATA" "$1"; }

case "${1:?usage: tl-standards run|findings|report ID}" in
  run)
    id="${2:?}"; wt="$(tl_meta_get "$id" worktree)"; base="$(tl_meta_get "$id" base)"; pname="$(tl_meta_get "$id" pname)"
    ppath="$("$BIN/tl-project.sh" get "$pname" path 2>/dev/null || true)"
    : "${TL_STANDARDS_CMD:?tl: no Standards reviewer — set TL_STANDARDS_CMD (e.g. adapters/claude-standards.sh)}"
    # the repo's documented standards: AGENTS.md (canonical, §2.7 + q3) + this instance's review-rubric.md
    std="$(mktemp)"
    for f in "$ppath/AGENTS.md" "$TL_LEAD/review-rubric.md"; do
      [ -f "$f" ] && { printf '\n# from %s\n' "$f"; cat "$f"; } >> "$std"
    done
    diff="$(mktemp)"; git -C "$wt" --no-pager diff "$base"..HEAD > "$diff" 2>/dev/null || true
    ff="$(ff_path "$id")"; mkdir -p "$(dirname "$ff")"
    TL_ST_ID="$id" TL_ST_STANDARDS="$std" TL_ST_DIFF="$diff" $TL_STANDARDS_CMD > "$ff" || true
    rm -f "$std" "$diff"
    v="$(awk -F'\t' '$1=="standards-violation"{c++} END{print c+0}' "$ff")"
    s="$(awk -F'\t' '$1=="standards-smell"{c++} END{print c+0}' "$ff")"
    echo "tl: standards axis — $((v+s)) finding(s): $v documented-violation, $s smell (draft, non-blocking)" >&2
    ;;
  findings)  # emit rule<TAB>detail<TAB>path (for #58 composition)
    id="${2:?}"; ff="$(ff_path "$id")"; [ -f "$ff" ] && cat "$ff" || true
    ;;
  report)  # human draft — the owner disposes (q2, draft-only)
    id="${2:?}"; ff="$(ff_path "$id")"; [ -f "$ff" ] || { echo "no standards findings for $id (run tl-standards run $id)"; exit 0; }
    [ -s "$ff" ] || { echo "Standards: clean — no findings"; exit 0; }
    awk -F'\t' '{m=($1=="standards-violation"?"[VIOLATION]":"[smell]    "); printf "%s %s  (%s)\n",m,$2,$3}' "$ff"
    ;;
  *) tl_die "usage: tl-standards run|findings|report ID";;
esac
