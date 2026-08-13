#!/usr/bin/env bash
# claude-propose.sh — drafts a candidate lead/ entry from a triggering case (§2.5/§2.6, E7.4/E7.5),
# Claude headless. TL_PROP_TYPE=rule -> a lead/principles.md rule (SHAPE.md form); =question -> a
# lead/questions.md entry. The draft ARTICULATES the owner's OWN decision as a reusable rule/question —
# it is not imported judgement; the owner still edits and promotes it. Prompted, not trained.
# Wire with: export TL_PROPOSE_CMD="$TL_HOME/adapters/claude-propose.sh"
set -eu
case_text="$(cat "${TL_PROP_CASE:?}" 2>/dev/null || true)"
if [ "${TL_PROP_TYPE:?}" = rule ]; then
  shape='a lead/principles.md rule in this shape: a "### <name>" heading; a "hits: 0   last: —" line; "**Ladder:**" a numbered decision procedure with stop conditions; "**Not when:**" where it must not apply; "**Intensity:** off | default | strict"; "**Persists:** every response; applies when uncertain; off only by the owner."'
  what='rule that, had it existed, would have made the lead infer what the owner corrected TO'
else
  shape='a lead/questions.md entry: a single "### <question>" phrased the way the owner would ask it, a "hits: 0   last: —" line, and a one-line "_scar:_ <what went wrong>".'
  what='question the grill should have asked at spec time, so this class of interruption happens once'
fi
prompt="You are drafting a CANDIDATE $what, for the owner to review and promote. Draft $shape

Base it STRICTLY on the owner's own decision in the case below — generalise it just enough to be
reusable, and never import outside judgement. Output ONLY the drafted markdown, nothing else.

Triggering case:
$case_text"
out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 3 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "(proposal)" propose || true
printf '%s' "$out" | jq -r '.result'
