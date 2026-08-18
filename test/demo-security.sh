#!/usr/bin/env bash
# demo-security.sh — deterministic Security judge for tests. Behaviour fixed by TL_DEMO_SEC_MODE
# (findings|clean|malformed|crash). A real judge reads the diff at TL_SEC_DIFF.
set -eu
case "${TL_DEMO_SEC_MODE:-findings}" in
  clean) ;;
  findings)
    printf 'security-vulnerability\tf.txt: hardcoded credential in the added hunk\tf.txt\n' ;;
  malformed)
    printf 'this is not a finding line at all\n' ;;
  crash)
    echo "demo-security: simulated harness failure" >&2; exit 1 ;;
esac
