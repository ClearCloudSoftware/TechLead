#!/usr/bin/env bash
# tl-kickoff.sh — persist the CONTEXT.md an ideation/brainstorm produced for a GREENFIELD project
# (E9.2 follow-up, #60). The interview itself happens in the operator's chat (the techlead skill,
# which may lean on the brainstorming skill) — NOT here: no LLM in the supervision loop. This is the
# deterministic persist step. It reads the composed CONTEXT.md on stdin, refuses to overwrite an
# existing one, writes it UNCOMMITTED (the domain is the owner's to approve), and prints the review +
# seed-backlog next steps. For a BROWNFIELD repo, tl-scaffold-context derives CONTEXT.md from the code.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
# <project> is optional: run from inside the project and it defaults to the one registered there.
name="${1:-}"
if [ -z "$name" ]; then
  name="$(tl_current_project)" || tl_die "run from inside a project (or pass its name). Registered here: $(ls "$TL_DATA/projects" 2>/dev/null | sed 's/\.conf$//' | tr '\n' ' ')"
fi
path="$("$BIN/tl-project.sh" get "$name" path)" || tl_die "unknown project: $name (tl-new/tl-onboard it first)"
target="$path/CONTEXT.md"
if [ -e "$target" ]; then tl_die "$target already exists — edit it by hand (refusing to overwrite)"; fi

content="$(cat)"   # the composed CONTEXT.md, piped in from the ideation
[ -n "$content" ] || tl_die "no CONTEXT.md content on stdin — compose it from the ideation, then pipe it in"
printf '%s\n' "$content" > "$target"

echo "tl: wrote $target (uncommitted)."
echo "tl: REVIEW it — it's your project's domain, yours to approve. Then commit so the grill/review/answer read it:"
echo "      git -C \"$path\" add CONTEXT.md && git -C \"$path\" commit -m 'add CONTEXT.md'"
echo "tl: then seed the backlog from the ideation (one per behaviour):"
echo "      tl-backlog add <slug> \"<title>\" [description]"
