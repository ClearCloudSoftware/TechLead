#!/usr/bin/env bash
# demo-answer.sh — deterministic inward-answer engine for tests. Plain-searches the corpus for the
# question's longest word; cites the SOURCE block it hit (flagging superseded/rejected Status), or answers
# "I don't know" when nothing matches. A real engine (claude-answer.sh) reasons over the whole corpus.
set -eu
q="${TL_ANS_Q:?}"; corpus="${TL_ANS_CORPUS:?}"
key="$(printf '%s' "$q" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '\n' | awk '{print length, $0}' | sort -rn | awk 'NR==1{print $2}')"
n="$(grep -in -- "$key" "$corpus" 2>/dev/null | head -1 | cut -d: -f1 || true)"
if [ -z "$n" ]; then echo "I don't know — no basis in your notes."; exit 0; fi
hit="$(sed -n "${n}p" "$corpus")"
s="$(awk -v n="$n" '/===== SOURCE:/{last=NR; name=$0} NR==n{print last"\t"name; exit}' "$corpus")"
sline="${s%%	*}"; sname="$(printf '%s' "${s#*	}" | sed 's/===== SOURCE: //; s/ =====//')"
e="$(awk -v s="$sline" 'NR>s && /===== SOURCE:/{print NR-1; exit}' "$corpus")"; [ -n "$e" ] || e="$(awk 'END{print NR}' "$corpus")"
# quote the source's substantive content (skip the SOURCE header, markdown headings, and Status: lines)
content="$(sed -n "${sline},${e}p" "$corpus" | grep -vE '^===== SOURCE:|^#|^Status:|^[[:space:]]*$' | head -1)"
[ -n "$content" ] || content="$hit"
if sed -n "${sline},${e}p" "$corpus" | grep -qiE 'status:[[:space:]]*(supersed|rejected)'; then
  printf 'Per %s — but that decision is SUPERSEDED, not current: %s\n' "$sname" "$content"
else
  printf 'Per %s: %s\n' "$sname" "$content"
fi
