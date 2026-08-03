#!/usr/bin/env bash
# tl-deliver.sh — deliver a change task (§2.2, §3.9). Runs the self-edit guard and the delivery
# gate first; only if both pass does it open a PR (mode=pr) or fast-forward merge (mode=local-only).
# The gate is a removed capability, not an instruction: this path simply will not deliver while a
# finding is unresolved.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-deliver ID}"
[ "$(tl_meta_get "$id" kind)" = change ] || tl_die "deliver is for change tasks"
project="$(tl_meta_get "$id" project)"; wt="$(tl_meta_get "$id" worktree)"
branch="$(tl_meta_get "$id" branch)"; base="$(tl_meta_get "$id" base)"; pname="$(tl_meta_get "$id" pname)"
mode="$("$BIN/tl-project.sh" get "$pname" mode 2>/dev/null || echo pr)"
defbranch="$("$BIN/tl-project.sh" get "$pname" default_branch 2>/dev/null || echo main)"

"$BIN/tl-guard-selfedit.sh" "$project"          # §3.9 E4.4 — refuse if primary is on a worker branch
"$BIN/tl-gate.sh" "$id"                          # §3.13 E4.2/3/6 — refuse while any finding is open

ahead="$(git -C "$wt" rev-list --count "$base"..HEAD 2>/dev/null || echo 0)"
[ "${ahead:-0}" -gt 0 ] || tl_die "nothing to deliver — no commits on $branch"

case "$mode" in
  local-only)
    git -C "$project" merge --ff-only "$branch" >/dev/null 2>&1 \
      || tl_die "not fast-forwardable into $defbranch — rebase the worker branch first"
    tl_meta_set "$id" delivered "ff-merge:$defbranch"
    tl_log "delivered $id — fast-forward merged $branch into $defbranch"
    "$BIN/tl-search.sh" refresh "$pname" >&2 || true   # brief D2 refresh trigger: landed code moved the map (fail-open, no-LLM)
    ;;
  pr)
    git -C "$wt" push -u origin "$branch" >/dev/null 2>&1 || tl_die "push of $branch failed"
    url="$(cd "$wt" && gh pr create --fill --head "$branch" 2>/dev/null)" || tl_die "gh pr create failed"
    tl_meta_set "$id" pr "$url"; tl_meta_set "$id" delivered "pr:$url"
    tl_log "delivered $id — PR $url"
    # tl: graph refresh waits for the PR to actually merge (not tracked in Phase 0) — refresh manually
    # (tl-search build "$pname") or on the next survey, so the map never reflects unmerged code.
    ;;
  *) tl_die "unknown delivery mode: $mode" ;;
esac
