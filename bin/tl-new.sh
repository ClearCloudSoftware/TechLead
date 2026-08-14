#!/usr/bin/env bash
# tl-new.sh — greenfield project wizard (§2.7, E11/W7). Creates an EMPTY git repo in the current
# directory (or $TL_PROJECTS_DIR if the operator set a fixed home) and registers it at
# readiness=survey — a repo with no tests can only take `plan`
# tasks. It grows through TechLead's own loop: early plan tasks set up structure + a test harness,
# which promotes it to `ready` for `change` tasks. It does NOT scaffold an app framework — that is
# not TechLead's job. Orchestrator, not owner: registration goes through tl-project (§3.1).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

name=""
while [ $# -gt 0 ]; do case "$1" in
  --yes|-y) TL_YES=1; shift;;
  -h|--help) echo "usage: tl-new <name>   (creates ./<name> here — or \$TL_PROJECTS_DIR/<name> if set; registered at readiness=survey)"; exit 0;;
  -*) tl_die "unknown arg: $1";;
  *) name="$1"; shift;;
esac; done
[ -n "$name" ] || tl_die "usage: tl-new <name>"
case "$name" in */*|.*) tl_die "name must be a bare directory name (got: $name)";; esac

# Create in the CURRENT directory by default — like `git init` / `cargo new`, so `tl-new foo` from your
# projects folder lands `./foo`, not somewhere surprising. An operator who wants a fixed home for new
# projects can set TL_PROJECTS_DIR (§3.2, "projects can live anywhere"); unset/empty -> create here.
parent="${TL_PROJECTS_DIR:-$PWD}"
target="$parent/$name"
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

# Per-project state (owner decision 2026-08-14): this repo's data/state/lead live in its own
# .techlead/, not TL_HOME. Scaffold it and point the registry writes below at it by exporting the
# paths (tl-common honours an already-set TL_DATA/TL_STATE/TL_LEAD, so the sub-processes target the
# project we are creating regardless of the current working directory).
tl_scaffold_project "$abs"
export TL_DATA="$abs/.techlead/data" TL_STATE="$abs/.techlead/state" TL_LEAD="$abs/.techlead/lead"

pj() { "$BIN/tl-project.sh" set "$name" "$@"; }
pj path "$abs"
pj mode local-only            # no remote yet → fast-forward locally
pj default_branch main
pj max_files_changed 25
pj readiness survey           # §2.7: no baseline yet → plan-only until a test harness exists

tl_log "created + registered '$name' (readiness=survey, plan-only) — $abs"
printf 'tl: next → cd %s, add a backlog item to .techlead/data/backlog.md, then grill a first plan\n' "$name" >&2
printf 'tl:        task to set up structure + a test\n' >&2
printf 'tl:        harness. Once tests exist, tl-baseline promotes it to ready for change tasks.\n' >&2
