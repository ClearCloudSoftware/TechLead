#!/usr/bin/env bash
# claude-scaffold-context.sh — draft one onboarding doc for a project (#60), backed by Claude headless.
# TL_CTX_DOC selects which: AGENTS.md (layout + how to run tests + current/superseded conventions +
# danger zones) or CONTEXT.md (domain glossary/jargon). Reads the repo (file list + a few key files)
# and emits ONLY the doc's markdown. Owner reviews + commits. Draft, never judgment.
# Wire with: export TL_SCAFFOLD_CONTEXT_CMD="$TL_HOME/adapters/claude-scaffold-context.sh"
set -eu
proj="${TL_CTX_PROJECT:?}"; doc="${TL_CTX_DOC:?}"
tree="$( (cd "$proj" && git ls-files 2>/dev/null | head -200) || true )"
# a little source to ground it: READMEs + the top of a few tracked files (no secrets — tracked only)
key="$( (cd "$proj" && git ls-files 2>/dev/null | grep -iE 'readme|package.json|Cargo.toml|go.mod|pyproject|makefile' | head -5 | while IFS= read -r f; do printf '\n===== %s =====\n' "$f"; head -60 "$f"; done) || true )"

case "$doc" in
  AGENTS.md) want="an AGENTS.md: the repo's operating map for a coding agent — directory layout, how to
build and run the tests, the CURRENT conventions AND any superseded/deprecated ones still visible in the
tree, and the danger zones (paths where a change is high-risk). Terse, scannable, no fluff.";;
  CONTEXT.md) want="a CONTEXT.md: the project's domain glossary — the nouns and jargon of this codebase,
each defined in one line, so one word can replace a paragraph in a spec or review. Only terms that carry
project-specific meaning; skip generic programming vocabulary.";;
  *) want="a concise $doc for this project.";;
esac

prompt="Write $want

Project file list:
$tree

Key files (excerpts):
$key

Output ONLY the markdown contents of $doc — no fences, no preamble. If the repo is nearly empty, write
a short honest skeleton with the right headings and TODOs rather than inventing detail."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 6 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_CTX_NAME:-scaffold-context}" scaffold-context || true
printf '%s' "$out" | jq -r '.result' | grep -v '^```'
