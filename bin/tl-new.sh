#!/usr/bin/env bash
# tl-new.sh — greenfield project wizard (§2.7, E11/W7). Creates an EMPTY git repo under
# TL_PROJECTS_DIR and registers it at readiness=survey — a repo with no tests can only take `plan`
# tasks. It grows through TechLead's own loop: early plan tasks set up structure + a test harness,
# which promotes it to `ready` for `change` tasks. It does NOT scaffold an app framework — that is
# not TechLead's job. Orchestrator, not owner: registration goes through tl-project (§3.1).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

name=""
while [ $# -gt 0 ]; do case "$1" in
  --yes|-y) TL_YES=1; shift;;
  -h|--help) echo "usage: tl-new <name>   (creates \$TL_PROJECTS_DIR/<name>, registered at readiness=survey)"; exit 0;;
  -*) tl_die "unknown arg: $1";;
  *) name="$1"; shift;;
esac; done
[ -n "$name" ] || tl_die "usage: tl-new <name>"
case "$name" in */*|.*) tl_die "name must be a bare directory name (got: $name)";; esac

# TL_PROJECTS_DIR is the home for NEW projects only (set by tl-init); tl-new owns its default.
TL_PROJECTS_DIR="${TL_PROJECTS_DIR:-$TL_HOME/projects}"
target="$TL_PROJECTS_DIR/$name"
[ -e "$target" ] && tl_die "$target already exists — use 'tl-onboard $target' to register an existing repo"

mkdir -p "$target"
git -C "$target" init -q -b main
# Seed one empty commit so worktrees can branch from a HEAD (the first plan task lands in a worktree).
# ponytail: empty commit is the git-level minimum to make the repo branchable — not app scaffolding.
# Set a local identity only if none is inherited, so first-run/CI works but the operator's own config
# wins when present.
if ! git -C "$target" config user.email >/dev/null 2>&1; then
  git -C "$target" config user.email "techlead@localhost"
  git -C "$target" config user.name  "TechLead"
fi
git -C "$target" commit --allow-empty -q -m "chore: initialize repository"
abs="$(cd "$target" && pwd -P)"   # canonicalize symlinks (macOS /var -> /private/var)

pj() { "$BIN/tl-project.sh" set "$name" "$@"; }
pj path "$abs"
pj mode local-only            # no remote yet → fast-forward locally
pj default_branch main
pj max_files_changed 25
pj readiness survey           # §2.7: no baseline yet → plan-only until a test harness exists

tl_log "created + registered '$name' (readiness=survey, plan-only) — $abs"
printf 'tl: next → add a backlog item, then grill a first plan task to set up structure + a test\n' >&2
printf 'tl:        harness. Once tests exist, tl-baseline promotes it to ready for change tasks.\n' >&2
