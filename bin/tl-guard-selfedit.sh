#!/usr/bin/env bash
# tl-guard-selfedit.sh — when the lead dispatches work on its OWN repo, a worker can branch and
# commit in the primary checkout instead of its worktree, stranding the primary on a feature
# branch (§3.9). Detect exactly that: a worker branch (tl/*) checked out at the project root.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
project="${1:?usage: tl-guard-selfedit PROJECT}"
cur="$(git -C "$project" rev-parse --abbrev-ref HEAD 2>/dev/null || echo DETACHED)"
case "$cur" in
  tl/*) tl_die "self-edit tangle: primary checkout of $project is on worker branch '$cur' (must be a base branch)" 4 ;;
esac
exit 0
