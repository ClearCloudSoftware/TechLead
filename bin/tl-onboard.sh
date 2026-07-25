#!/usr/bin/env bash
# tl-onboard.sh — brownfield project wizard (§2.7, E11/W3). Registers an EXISTING repo in place, by
# absolute path (the repo never moves). It proposes W4-detected defaults, confirms each with the
# owner, then registers via tl-project and captures a baseline via tl-baseline. Orchestrator, not
# owner (§3.1): every registry write goes through tl-project — this script never touches the .conf.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

raw=""
while [ $# -gt 0 ]; do case "$1" in
  --yes|-y) TL_YES=1; shift;;
  -h|--help) echo "usage: tl-onboard <repo-path> [--yes]   (non-interactive: --yes or TL_ANSWER_* env)"; exit 0;;
  -*) tl_die "unknown arg: $1";;
  *) raw="$1"; shift;;
esac; done
[ -n "$raw" ] || tl_die "usage: tl-onboard <repo-path> [--yes]"
[ -d "$raw" ] || tl_die "no such directory: $raw"

# Normalise to the repo's toplevel and canonicalise symlinks (macOS /var -> /private/var) so the
# registered path matches what git resolves worktrees against later.
path="$(cd "$raw" && git rev-parse --show-toplevel 2>/dev/null)" \
  || tl_die "not a git repo: $raw  (run 'git init' there, or use tl-new for a brand-new project)"
path="$(cd "$path" && pwd -P)"
det() { "$BIN/tl-detect.sh" "$1" "$path"; }

name="$(tl_ask NAME "project name (registry key)" "$(basename "$path")")"
tl_log "onboarding '$name' — $path"

mode="$(tl_ask MODE "delivery mode (local-only|pr)" "$(det mode)")"
branch="$(tl_ask BRANCH "default branch (merge target)" "$(det branch)")"
test_command="$(tl_ask TEST_COMMAND "test command — must print failing-test ids, one per line" "$(det test-command)")"
max_files="$(tl_ask MAX_FILES "max files changed before it becomes an ask-user finding" "25")"
danger="$(tl_ask DANGER_PATHS "danger-path globs (space-separated), touching one escalates" "$(det danger-paths)")"

# Register through the single owner (§3.12) — never a direct .conf write.
pj() { "$BIN/tl-project.sh" set "$name" "$@"; }
pj path "$path"
pj mode "$mode"
pj default_branch "$branch"
pj max_files_changed "$max_files"
[ -n "$test_command" ] && pj test_command "$test_command"
[ -n "$danger" ]       && pj danger_paths "$danger"

# Baseline — the completion criterion for a brownfield `change` (§2.7). Only with an explicit OK to
# run the tests, and only if a test command exists. A recorded baseline promotes readiness to
# `ready` (all kinds); without one the repo stays at `survey` (plan-only) — the safe tier.
ready=survey
if [ -n "$test_command" ] && tl_confirm RUN_BASELINE "run the test command now to capture the baseline" "y"; then
  "$BIN/tl-baseline.sh" "$name"
  ready=ready
elif [ -z "$test_command" ]; then
  tl_log "no test command → staying at readiness=survey (plan-only until a harness exists)"
else
  tl_log "baseline skipped → staying at readiness=survey; re-run tl-baseline $name to promote to ready"
fi
pj readiness "$ready"

tl_log "registered '$name' (readiness=$ready)"
printf 'tl: next → add a backlog item to data/backlog.md, then grill it:  tl-grill <slug>\n' >&2
