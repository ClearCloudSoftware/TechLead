#!/usr/bin/env bash
# tl-worktree.sh — the ONLY file that knows how worktrees are provisioned (§3.11).
# Two functions, acquire + release. Backed by plain `git worktree` (D9); swapping in
# treehouse later is a change here and nowhere else.
# tl: plain git worktree, no pool — swap to treehouse if dep-reinstall cost dominates (D9, §3.11)

. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/tl-common.sh"

tl_worktree_acquire() { # project id -> prints the worktree path
  local project="$1" id="$2" path
  git -C "$project" rev-parse --git-dir >/dev/null 2>&1 || tl_die "not a git repo: $project"
  path="$TL_WORKTREES/$id"
  [ -e "$path" ] && tl_die "worktree path already exists: $path"
  git -C "$project" worktree add --detach "$path" >/dev/null 2>&1 || tl_die "git worktree add failed for $project -> $path"
  printf '%s\n' "$path"
}

tl_worktree_release() { # project id path
  local project="$1" id="$2" path="$3" holder
  # §3.9: refuse to return a worktree this task does not hold.
  holder="$(tl_meta_get "$id" worktree 2>/dev/null || true)"
  [ "$holder" = "$path" ] || tl_die "refusing release — $id does not hold $path (holds: ${holder:-none})"
  git -C "$project" worktree remove --force "$path" >/dev/null 2>&1 || tl_die "git worktree remove failed: $path"
}
