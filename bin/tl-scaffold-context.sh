#!/usr/bin/env bash
# tl-scaffold-context.sh — draft a project's onboarding docs (§2.7, E9.2/#60) as real files:
#   AGENTS.md  — layout, how to run tests, current *and* superseded conventions, danger zones
#   CONTEXT.md — the domain glossary/vocabulary that lets one word replace a paragraph
# The onboarding survey is a PLAN task, so it can only describe these in a report — it can't write
# them. This writes them for real. DRAFT-then-approve: it writes each missing doc, then STOPS. The
# first CONTEXT.md warrants owner review (§8.21), so it never commits and never overwrites an existing
# doc. Once committed, the grill/review/answer read them (a worker's worktree branches from HEAD).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
name="${1:-}"
[ -n "$name" ] || name="$(tl_current_project)" || tl_die "run from inside a project (or pass its name). Registered here: $(ls "$TL_DATA/projects" 2>/dev/null | sed 's/\.conf$//' | tr '\n' ' ')"
path="$("$BIN/tl-project.sh" get "$name" path)" || tl_die "unknown project: $name (run from inside it, or tl-onboard/tl-new it first)"

scaffolder="${TL_SCAFFOLD_CONTEXT_CMD:-}"
if [ -z "$scaffolder" ]; then
  tl_die "no scaffolder configured (TL_SCAFFOLD_CONTEXT_CMD; tl-init wires it for the claude harness).
  Write $path/AGENTS.md (layout + conventions + danger zones) and $path/CONTEXT.md (domain glossary) by hand."
fi

wrote=""
for doc in AGENTS.md CONTEXT.md; do
  target="$path/$doc"
  if [ -e "$target" ]; then tl_log "skip $doc — already exists (refusing to overwrite)"; continue; fi
  tl_log "scaffold-context: drafting $doc for '$name' (calling scaffolder)…"
  draft="$(TL_CTX_NAME="$name" TL_CTX_PROJECT="$path" TL_CTX_DOC="$doc" $scaffolder || true)"
  if [ -z "$draft" ]; then tl_log "scaffolder produced nothing for $doc — draft it by hand"; continue; fi
  printf '%s\n' "$draft" > "$target"; wrote="$wrote $doc"
done

[ -n "$wrote" ] || tl_die "nothing drafted (both docs exist, or the scaffolder produced nothing)"
echo "tl: drafted$wrote in $path."
echo "tl: REVIEW them — the first CONTEXT.md especially is yours to check (§8.21). Then commit so the"
echo "    grill/review/answer can read them (workers branch from HEAD):"
echo "      git -C \"$path\" add$(printf ' %s' $wrote) && git -C \"$path\" commit -m 'add onboarding docs'"
