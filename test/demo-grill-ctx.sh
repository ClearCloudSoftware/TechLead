#!/usr/bin/env bash
# demo-grill-ctx.sh — reports (as the question text) whether the project's context docs reached the
# driver via TL_CONTEXT, so the grill→context wiring (#60) can be tested deterministically.
set -eu
if grep -q 'widget' "${TL_CONTEXT:-/dev/null}" 2>/dev/null; then tag=CTX-SEEN; else tag=CTX-MISSING; fi
printf 'q1\tdecided\tinferred\t%s\n' "$tag"
