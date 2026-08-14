#!/usr/bin/env bash
# tl-propose.sh — the shared propose-not-write mechanism for the two judgment feedback loops (§2.5/§2.6,
# E7.4/E7.5, #51/#52). Both loops turn a triggering case into an LLM-DRAFTED candidate for lead/ — but
# candidates land in data/proposals/ (OUTSIDE lead/), clearly "not yet judgment", for the owner to edit
# and promote. Nothing is ever written into lead/ (owner-only). Idempotent: a proposal for a given
# (type,key) is drafted once.
#
# Usage: tl-propose rule|question <key> <case-file>
#   rule     -> a candidate lead/principles.md rule (from an owner override, #51)
#   question -> a candidate lead/questions.md entry (from a worker escalation, #52)
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
type="${1:?usage: tl-propose rule|question <key> <case-file>}"; key="${2:?key}"; casef="${3:?case-file}"
case "$type" in rule|question) ;; *) tl_die "type must be rule or question";; esac
[ -f "$casef" ] || tl_die "no case file: $casef"

dir="$TL_DATA/proposals"; mkdir -p "$dir"
out="$dir/${type}-${key}.md"
[ -f "$out" ] && { echo "tl: proposal already exists, skipping: ${out#"$TL_DATA"/}"; exit 0; }   # idempotent

: "${TL_PROPOSE_CMD:?tl: no proposer — set TL_PROPOSE_CMD (e.g. adapters/claude-propose.sh)}"
draft="$(TL_PROP_TYPE="$type" TL_PROP_KEY="$key" TL_PROP_CASE="$casef" $TL_PROPOSE_CMD || true)"
[ -n "$draft" ] || draft="_(proposer produced nothing — draft the ${type} by hand from the case below)_"

{
  printf '# Candidate %s — for your review (NOT yet in lead/)\n\n' "$type"
  # source label: callers may set TL_PROP_SOURCE (e.g. grill propose-mode = "backlog item"); else the
  # loop that drove it — override (#51) or worker escalation (#52).
  printf '> Auto-drafted from a real %s. This is a proposal in `data/proposals/`, derived from YOUR own\n' \
    "${TL_PROP_SOURCE:-$([ "$type" = rule ] && echo override || echo "worker escalation")}"
  printf '> decision — edit it and promote it into `lead/` yourself, or delete it. Nothing lands in lead/ without you.\n\n'
  printf '## Triggering case\n\n```\n'; cat "$casef"; printf '\n```\n\n'
  printf '## Drafted candidate (%s)\n\n' "$([ "$type" = rule ] && echo 'lead/principles.md' || echo 'lead/questions.md')"
  printf '%s\n' "$draft"
} > "$out"
echo "tl: queued proposal -> ${out#"$TL_DATA"/}  (review, then promote into lead/ by hand)"
