#!/usr/bin/env bash
# demo-grill-propose.sh — deterministic propose-mode driver for the smoke test. Emits a fixed set of
# candidate questions (h3 headings + rationale) so propose→prune→promote can be tested without a model.
set -eu
cat <<'EOF'
### What is the exact interface and where does it live?
_why:_ pins the signature before code so the worker doesn't guess.
### What are the edge cases and error behavior?
_why:_ the gaps that bite in review if unspecified.
### How is "done" proven — what test?
_why:_ ties the change to a failing-id the gate can check.
EOF
