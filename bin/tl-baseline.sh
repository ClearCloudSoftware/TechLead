#!/usr/bin/env bash
# tl-baseline.sh — capture a project's known-failing test set (§2.7, §3.12). Without it a brownfield
# change has no completion criterion: workers compare against this baseline, not against green.
# The test command must print failing-test identifiers, one per line (a project adapter's job).
# tl: `eval` on operator-configured command — trusted registry only, never worker input
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
name="${1:-}"
[ -n "$name" ] || name="$(tl_current_project)" || tl_die "run from inside a project (or pass its name). Registered here: $(ls "$TL_DATA/projects" 2>/dev/null | sed 's/\.conf$//' | tr '\n' ' ')"
path="$("$BIN/tl-project.sh" get "$name" path)"         || tl_die "unknown project: $name"
cmd="$("$BIN/tl-project.sh" get "$name" test_command)"  || tl_die "no test_command for $name"
out="$TL_DATA/projects/$name.baseline"

echo "tl: capturing baseline for $name  ($cmd)"
# Redirections stay inside the command so the spinner has nothing to swallow or merge (see tl_spin).
tl_spin "running the test suite…" \
  sh -c "cd '$path' && { $cmd; } 2>/dev/null | sort -u > '$out'" || true
"$BIN/tl-project.sh" set "$name" baseline "$out"
"$BIN/tl-project.sh" set "$name" baseline_at "$(date -u +%Y-%m-%d)"
echo "tl: baseline recorded — $(grep -c . "$out" 2>/dev/null || echo 0) known-failing test(s)"

# The baseline was just run against the WORKING TREE; a worker's gate reruns test_command against
# committed state (§2.7). If the tree is dirty the two disagree — most often because the harness
# itself isn't committed, exactly what makes a worker run blind. Say so here, at the promote moment.
tl_warn_uncommitted "$path" "Commit them (especially the test harness) before dispatching change tasks, or the gate runs a different test than this baseline." || true

# A captured baseline is the completion criterion a `change` needs, so a survey (plan-only) project
# graduates to `ready` here — exactly as tl-new and the tutorial promise. Leave ready/assisted as-is
# (re-baselining an established project must not change its readiness).
if [ "$("$BIN/tl-project.sh" get "$name" readiness 2>/dev/null || true)" = survey ]; then
  "$BIN/tl-project.sh" set "$name" readiness ready
  echo "tl: $name promoted survey → ready (change tasks now allowed)"
fi
