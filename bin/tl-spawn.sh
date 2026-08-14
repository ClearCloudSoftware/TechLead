#!/usr/bin/env bash
# tl-spawn.sh — dispatch one task into an isolated worktree (§3.9, §3.11). Phase 0: plan | change.
#
# Usage:
#   tl-spawn <id> [overrides...]     # <id> is the spec/task id; brief/project/project-name/kind are
#                                    #   resolved from the spec + registry (deterministic, never guessed)
#   tl-spawn --id <id> [flags...]    # explicit form — every field can be a flag (the manual path)
#
# Resolution (each field: explicit flag wins, then spec, then registry/readiness; otherwise a NAMED
# refusal — never a silent wrong default):
#   brief         --brief  > data/<id>/brief.md (if present)
#   project-name  --project-name > spec `project` (if registered) > the sole registered project
#   project path  --project > registry path(project-name)
#   kind          --kind > spec `kind` > project readiness (survey→plan, ready/assisted→change)
# The spec may pin `project`/`kind` via `tl-spec set <id> <field> <value>`. Explicit flags always win,
# so the full-flag form stays 100% backward compatible.
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
    -h|--help) echo "usage: tl-spawn <id> [--project DIR] [--project-name NAME] [--kind plan|change] [--brief FILE]"; exit 0;;
    -*) tl_die "unknown arg: $1";;
    *) [ -z "$id" ] && id="$1" || tl_die "unexpected argument: $1"; shift;;
  esac
done
[ -n "$id" ] || tl_die "usage: tl-spawn <id> [overrides]   (<id> is the spec/task id)"
[ -f "$(tl_meta_file "$id")" ] && tl_die "task $id already exists"

# ---- deterministic resolution from existing state (§3.1: read owners, never re-derive) ----
spec="$("$BIN/tl-spec.sh" path "$id" 2>/dev/null || true)"
sget() { [ -f "$spec" ] || return 0; "$BIN/tl-spec.sh" get "$id" "$1" 2>/dev/null || true; }
reg_has()  { [ -f "$TL_DATA/projects/$1.conf" ]; }
reg_path() { "$BIN/tl-project.sh" get "$1" path 2>/dev/null || true; }

# brief: flag > data/<id>/brief.md
if [ -z "$brief" ] && [ -f "$TL_DATA/$id/brief.md" ]; then brief="$TL_DATA/$id/brief.md"; fi

# project (path) + project-name (registry key).
if [ -n "$project" ]; then
  # an explicit --project is the trusted manual path: canonicalize it and name it from the registry
  # entry whose path matches (so the change gate still finds the config), else its basename.
  project="$(cd "$project" 2>/dev/null && pwd -P)" || tl_die "project path does not exist for '$id': $project"
  if [ -z "$pname" ]; then
    for c in "$TL_DATA"/projects/*.conf; do
      [ -f "$c" ] || continue; n="$(basename "$c" .conf)"
      if [ "$(reg_path "$n")" = "$project" ]; then pname="$n"; break; fi
    done
    [ -n "$pname" ] || pname="$(basename "$project")"
  fi
else
  # no explicit path → resolve the registry key (flag > spec `project` if registered > the sole
  # registered project), then take that entry's path.
  if [ -z "$pname" ]; then
    sp="$(sget project)"
    if [ -n "$sp" ] && reg_has "$sp"; then
      pname="$sp"
    else
      count=0; sole=""
      for c in "$TL_DATA"/projects/*.conf; do [ -f "$c" ] || continue; count=$((count + 1)); sole="$c"; done
      if [ "$count" -eq 1 ]; then pname="$(basename "$sole" .conf)"; fi
    fi
  fi
  if [ -n "$pname" ] && reg_has "$pname"; then project="$(reg_path "$pname")"; fi
  [ -n "$project" ] || tl_die "cannot resolve project for '$id' — pass --project, set it on the spec (tl-spec set $id project NAME), or register exactly one project"
  project="$(cd "$project" 2>/dev/null && pwd -P)" || tl_die "registered project path does not exist for '$pname': $project"
fi

# kind: flag > spec `kind` > project readiness (§2.7 ladder: survey→plan, ready/assisted→change)
if [ -z "$kind" ]; then kind="$(sget kind)"; fi
if [ -z "$kind" ] && reg_has "$pname"; then
  case "$("$BIN/tl-project.sh" get "$pname" readiness 2>/dev/null || true)" in
    survey) kind=plan;;
    ready|assisted) kind=change;;
  esac
fi
[ -n "$kind" ] || tl_die "cannot resolve kind for '$id' — pass --kind plan|change or set it on the spec (tl-spec set $id kind ...)"
case "$kind" in plan|change|review) ;; *) tl_die "kind must be plan, change, or review (got: $kind)";; esac
# review has no coding worker — its "workers" are the two review axes. It reviews an existing change,
# draft-only, so it is run directly rather than spawned into a worktree (§2.2, E8.6).
if [ "$kind" = review ]; then
  echo "tl: review is draft-only over an existing change — run:  tl-review <change-id>" >&2
  exit 0
fi
# NB: an explicit --project/--project-name is trusted even if unregistered (the manual path); the gate
# degrades safely for an unregistered project. Resolution from the spec only ever uses a registered
# name (checked above), so a phantom project can't be dispatched implicitly.

: "${TL_WORKER_CMD:?tl: no worker configured — set TL_WORKER_CMD to the harness adapter}"
tl_log "spawn $id — kind=$kind, project=$pname ($project), brief=${brief:-none}"

# Last chance to catch harness-invisibility: the worker's worktree branches from HEAD, so uncommitted
# project files (test harness, fixtures, the code under review) won't be there. Warn, don't block —
# the owner may have intentional WIP; but a blind worker on a fresh repo is almost always this.
tl_warn_uncommitted "$project" "This worker will not see them; commit first if it needs them." || true

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
