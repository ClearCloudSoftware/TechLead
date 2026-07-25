#!/usr/bin/env bash
# demo-grill.sh — deterministic inference driver for the grill smoke test. Emits one question per
# line: qid<TAB>answer_state<TAB>source<TAB>text. A real driver infers from lead/ + decisions/;
# this one is fixed (one inferred-decided, one open for the owner, one spike).
set -eu
printf 'q1\tdecided\tinferred\tReuse the existing secrets backend rather than introduce one?\n'
printf 'q2\topen\towner\tPer-environment rollout order?\n'
printf 'q3\tspike\towner\tRollback path if rotation fails mid-flight?\n'
