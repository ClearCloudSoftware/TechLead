#!/usr/bin/env bash
# demo-scaffold-context.sh — deterministic onboarding-doc scaffolder for tests. Emits a fixed skeleton
# for whichever doc TL_CTX_DOC selects, so tl-scaffold-context can be tested without a model.
set -eu
case "${TL_CTX_DOC:?}" in
  AGENTS.md)  printf '# AGENTS.md\n\n## Layout\n- src/ — code\n\n## Tests\n`sh test.sh`\n\n## Danger zones\n- test.sh\n';;
  CONTEXT.md) printf '# CONTEXT.md\n\n## Glossary\n- **widget** — the core domain noun.\n';;
  *) printf '# %s\n' "$TL_CTX_DOC";;
esac
