#!/usr/bin/env bash
# demo-propose.sh — deterministic proposer for tests. Emits a stub candidate keyed by TL_PROP_TYPE.
set -eu
if [ "${TL_PROP_TYPE:?}" = rule ]; then
  printf '### <name the rule from the case>\nhits: 0   last: —\n**Ladder:** 1. <stop condition>\n**Not when:** <exceptions>\n**Intensity:** off | default | strict\n**Persists:** every response; off only by the owner.\n'
else
  printf '### <the question, as the owner would ask it>\nhits: 0   last: —\n_scar:_ drawn from the case above.\n'
fi
