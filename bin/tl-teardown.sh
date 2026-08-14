#!/usr/bin/env bash
# tl-teardown.sh — retire a task safely (§3.9): refuse on unpushed work, release the worktree,
# kill the session. The report in data/ survives.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-worktree.sh"; . "$BIN/tl-session.sh"
. "$BIN/tl-wizard.sh"

id="${1:-$(tl_pick_task || true)}"; force="${2:-}"
[ -n "$id" ] || tl_die "usage: tl-teardown ID [--force]"
project="$(tl_meta_get "$id" project)" || tl_die "no such task: $id"
wt="$(tl_meta_get "$id" worktree)"
base="$(tl_meta_get "$id" base)"

if [ "$force" != "--force" ]; then
  # guard 1: uncommitted changes in the worktree
  if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
    tl_die "refusing teardown — $id has uncommitted changes in its worktree (use --force)"
  fi
  # guard 2: commits on tl/<id> beyond where it started, not yet delivered = unpushed work.
  # tl-deliver records `delivered` for BOTH paths — pr:<url> and ff-merge:<branch> — so that is the
  # single "this work left the worktree" signal. (Keying on `pr` alone refused every local-only/ff
  # delivery, which is tl-new's default, forcing --force on every greenfield teardown.)
  ahead="$(git -C "$wt" rev-list --count "$base"..HEAD 2>/dev/null || echo 0)"
  delivered="$(tl_meta_get "$id" delivered 2>/dev/null || true)"
  if [ "${ahead:-0}" -gt 0 ] && [ -z "$delivered" ]; then
    tl_die "refusing teardown — tl/$id has $ahead undelivered commit(s) (not merged or pushed) (use --force)"
  fi
fi

tl_session_kill "$id"
tl_worktree_release "$project" "$id" "$wt"
tl_meta_set "$id" state "done"
tl_log "torn down $id (report kept at $(tl_meta_get "$id" report))"
