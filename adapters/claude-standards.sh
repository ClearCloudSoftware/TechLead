#!/usr/bin/env bash
# claude-standards.sh — the Standards review axis (E8.1 / #53), backed by Claude headless. Standards is
# BORROWED craft, not TechLead judgement: it applies the vendored mattpocock/code-review Standards brief
# (12-smell Fowler baseline + two rules, pinned v1.2.0) against the repo's own documented standards
# (AGENTS.md + lead/review-rubric.md, which OVERRIDE the baseline). Draft-only — it never blocks (q2).
# Wire with: export TL_STANDARDS_CMD="$TL_HOME/adapters/claude-standards.sh"
#
# Contract: read the change diff from the file at TL_ST_DIFF and the repo's documented standards from the
# file at TL_ST_STANDARDS; emit ONE tab-separated line per finding: rule<TAB>detail<TAB>path
#   rule ∈ standards-violation (broke a documented rule — hard) | standards-smell (baseline — judgement call)
set -eu
brief="$(cat "$TL_HOME/.agents/skills/code-review-standards@1.2.0.md" 2>/dev/null || true)"
standards="$(cat "${TL_ST_STANDARDS:-/dev/null}" 2>/dev/null || true)"
[ -n "$standards" ] || standards="(no documented standards found — apply the baseline only)"
diff="$(cat "${TL_ST_DIFF:?}" 2>/dev/null || true)"

prompt="You are the Standards review axis. Apply this vendored brief exactly:
$brief

This repo's own documented standards (these OVERRIDE the baseline):
$standards

The change diff:
$diff

Emit ONLY one tab-separated line per finding and nothing else:
rule<TAB>detail<TAB>path
- rule = standards-violation when the diff breaks a rule the documented standards state (cite the rule)
- rule = standards-smell when it trips a baseline smell (name the smell) — always a judgement call
- detail = one line: what + where, quoting the hunk briefly; path = the file
Report nothing for clean hunks. Skip anything automated tooling enforces."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 4 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_ST_ID:-(standards)}" standards || true
printf '%s' "$out" | jq -r '.result' | awk -F'\t' 'NF>=3 && ($1=="standards-violation" || $1=="standards-smell")'
