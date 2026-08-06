#!/usr/bin/env bash
# demo-standards.sh — deterministic Standards judge for tests. Emits one of each rule-id (rule<TAB>detail
# <TAB>path). A real judge reads TL_ST_DIFF + TL_ST_STANDARDS and applies the vendored brief.
set -eu
printf 'standards-violation\tf.txt: breaks the documented naming rule (foo -> bar)\tf.txt\n'
printf 'standards-smell\tf.txt: Duplicated Code — the same block appears twice\tf.txt\n'
