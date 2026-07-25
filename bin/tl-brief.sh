#!/usr/bin/env bash
# tl-brief.sh — generate the disposable brief (how) from the durable spec (what/why) (§3.1, §3.10).
# REFUSES to brief an unspecified spec or one with open questions — that refusal is the whole point
# of the step, and it is a script-level guard, not a prompt instruction. Re-confirms answers older
# than the decay threshold (§2.6): a stale answer is worse than no answer.
# tl: BSD `date -j -f` for age — use `date -d` on GNU
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-brief ID}"
spec="$("$BIN/tl-spec.sh" path "$id")"; [ -f "$spec" ] || tl_die "no spec for $id"

state="$("$BIN/tl-spec.sh" get "$id" state)"
[ "$state" = specified ] || tl_die "refusing to brief $id — state is '$state', not 'specified'"
open="$("$BIN/tl-spec.sh" open-count "$id")"
[ "$open" -eq 0 ] || tl_die "refusing to brief $id — $open open question(s) remain"

# decay: refuse if any answer is older than the threshold (re-confirm via tl-grill answer)
decay="${TL_ANSWER_DECAY_DAYS:-30}"; now="$(date -u +%s)"; stale=0
while IFS='|' read -r qid st src at text; do
  [ -n "$qid" ] || continue
  aepoch="$(date -j -f %Y-%m-%d "$at" +%s 2>/dev/null || echo "$now")"
  age=$(( (now - aepoch) / 86400 ))
  if [ "$age" -gt "$decay" ]; then echo "tl: stale (${age}d) [$qid] $text" >&2; stale=$((stale + 1)); fi
done <<EOF
$("$BIN/tl-spec.sh" qlist "$id")
EOF
[ "$stale" -eq 0 ] || tl_die "refusing to brief $id — $stale answer(s) older than ${decay}d; re-confirm first"

brief="$TL_DATA/$id/brief.md"
title="$("$BIN/tl-spec.sh" get "$id" title)"; slug="$("$BIN/tl-spec.sh" get "$id" backlog)"
{
  printf '# Brief — %s\n\n**Task** `%s`  ·  **Backlog** `%s`  ·  disposable (how)\n\n' "$title" "$id" "$slug"
  echo "## Constraints (from the spec)"
  "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '
    $2=="decided" { printf "- **MUST** (%s): %s\n", $1, $5 }
    $2=="leaning" { printf "- default, may challenge (%s): %s\n", $1, $5 }
    $2=="spike"   { printf "- **SPIKE** (%s) — resolve by building: %s\n", $1, $5 }'
  printf '\n_Durable spec: %s_\n' "$spec"
} > "$brief"
echo "tl: brief written -> $brief"
