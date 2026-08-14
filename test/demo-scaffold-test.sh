#!/usr/bin/env bash
# demo-scaffold-test.sh — deterministic scaffolder for the smoke test. Emits a fixed test.sh (the
# failing-id-per-line contract) so tl-scaffold-test can be tested without a model.
set -eu
cat <<'EOF'
#!/bin/sh
# scaffolded harness (demo). One failing-id per unmet behaviour; silent when all pass.
[ "$(bash greet.sh 2>/dev/null)" = "hi" ] || echo greet-hi
EOF
