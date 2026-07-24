#!/usr/bin/env bash
# tl-spawn.sh — dispatch one task into an isolated worktree (§3.9, §3.11). Phase 0: plan | change.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"
. "$BIN/tl-common.sh"; . "$BIN/tl-worktree.sh"; . "$BIN/tl-session.sh"

id=""; project=""; kind=""; brief=""; pname=""
while [ $# -gt 0 ]; do
  case "$1" in
    --id) id="$2"; shift 2;;
    --project) project="$2"; shift 2;;
    --project-name) pname="$2"; shift 2;;
    --kind) kind="$2"; shift 2;;
    --brief) brief="$2"; shift 2;;
    *) tl_die "unknown arg: $1";;
  esac
done
[ -n "$id" ] && [ -n "$project" ] && [ -n "$kind" ] || tl_die "usage: tl-spawn --id ID --project DIR --kind plan|change [--brief FILE]"
case "$kind" in plan|change) ;; *) tl_die "kind must be plan or change in Phase 0 (got: $kind)";; esac
[ -f "$(tl_meta_file "$id")" ] && tl_die "task $id already exists"
: "${TL_WORKER_CMD:?tl: no worker configured — set TL_WORKER_CMD to the harness adapter}"

project="$(cd "$project" && pwd -P)"
pname="${pname:-$(basename "$project")}"   # registry key for the change gate (§3.12)
wt="$(tl_worktree_acquire "$project" "$id")"
wt="$(cd "$wt" && pwd -P)"   # canonicalize: git resolves symlinks (macOS /var -> /private/var)
# §3.9: spawn refuses unless the resolved path is a real worktree root distinct from the primary checkout.
top="$(cd "$(git -C "$wt" rev-parse --show-toplevel)" && pwd -P)"
[ "$top" = "$wt" ] || tl_die "resolved path is not a worktree root: $wt (top: $top)"
[ "$wt" != "$project" ] || tl_die "worktree equals primary checkout — refusing"

git -C "$wt" checkout -q -b "tl/$id"          # §3.11: worker branch from the detached HEAD it lands on
base="$(git -C "$wt" rev-parse HEAD)"
mkdir -p "$TL_DATA/$id"
report="$TL_DATA/$id/report.md"

tl_meta_set "$id" project  "$project"
tl_meta_set "$id" pname    "$pname"
tl_meta_set "$id" worktree "$wt"
tl_meta_set "$id" branch   "tl/$id"
tl_meta_set "$id" base     "$base"
tl_meta_set "$id" kind     "$kind"
tl_meta_set "$id" report   "$report"
tl_meta_set "$id" state    "working"

# Hand the worker its context via env; it writes its deliverable to $TL_REPORT (in data/, so it
# survives teardown and never dirties the worktree). tl: word-split cmd — fine for single-binary adapters.
TL_TASK_ID="$id" TL_TASK_KIND="$kind" TL_BRIEF="${brief:-}" TL_WORKTREE="$wt" TL_REPORT="$report" \
  tl_session_start "$id" "$wt" -- $TL_WORKER_CMD

tl_log "spawned $id ($kind) on tl/$id in $wt"
