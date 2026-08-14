#!/usr/bin/env bash
# claude-scaffold-test.sh — draft a test harness (test.sh) for a project from its backlog. Emits ONLY
# the file contents: a shell script that runs the app and echoes one failing-id per unmet behaviour,
# printing nothing when all pass (the TechLead failing-id-per-line contract). Owner reviews + approves.
# Wire with: export TL_SCAFFOLD_TEST_CMD="$TL_HOME/adapters/claude-scaffold-test.sh"
set -eu
backlog="$(cat "$TL_SCAFFOLD_BACKLOG" 2>/dev/null || true)"
tree="$( (cd "$TL_SCAFFOLD_PROJECT" && git ls-files 2>/dev/null | head -60) || true )"

prompt="Write a test harness named test.sh for this project. It MUST:
- be a shell script starting with '#!/bin/sh' — no test framework, plain shell + the app;
- check each behaviour in the backlog below;
- echo exactly ONE stable identifier per BROKEN behaviour (e.g. 'greet-hi'), one per line;
- print NOTHING on stdout when everything passes;
- exit 0 regardless — the ids printed to stdout are the signal, not the exit code.
This is the completion criterion TechLead workers build against: every not-yet-built behaviour should
print its id now and go silent once implemented. Keep ids short, stable, and behaviour-named.

Backlog (the behaviours to cover):
$backlog

Existing files (may be empty for a brand-new project):
$tree

Output ONLY the contents of test.sh — no markdown fences, no commentary."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_SCAFFOLD_NAME:-scaffold-test}" scaffold-test || true
# strip any accidental ``` fences the model wraps around the file
printf '%s' "$out" | jq -r '.result' | grep -v '^```'
