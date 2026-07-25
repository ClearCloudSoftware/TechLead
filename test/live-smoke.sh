#!/usr/bin/env bash
# live-smoke.sh — end-to-end integration test using a REAL local agent (opencode + a local model,
# default ollama/qwen3-coder:30b). Unlike the deterministic demo smokes, this drives the actual
# model, so it is slow (minutes) and asserts the OUTCOME — a farewell function delivered onto main —
# rather than exact intermediate output. Skips cleanly if opencode or the model isn't installed.
#
# Run:   ./test/live-smoke.sh            (uses ollama/qwen3-coder:30b)
#        TL_OPENCODE_MODEL=ollama/gemma4:26b ./test/live-smoke.sh
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
MODEL="${TL_OPENCODE_MODEL:-ollama/qwen3-coder:30b}"
fail() { echo "FAIL: $1"; exit 1; }

command -v opencode >/dev/null 2>&1 || { echo "SKIP: opencode not installed"; exit 0; }
command -v ollama   >/dev/null 2>&1 || { echo "SKIP: ollama not installed"; exit 0; }
ollama list | awk 'NR>1{print $1}' | grep -qx "${MODEL#ollama/}" \
  || { echo "SKIP: model ${MODEL#ollama/} not pulled"; exit 0; }

echo "== live integration via opencode + $MODEL (this takes a few minutes) =="
WORK="$(mktemp -d)"; PROJ="$WORK/proj"; INST="$WORK/inst"
mkdir -p "$INST/lead" "$INST/data"
cp "$REPO/AGENTS.md" "$INST/AGENTS.md"
ln -s "$REPO/bin" "$INST/bin"                       # a real instance has bin/ under TL_HOME
cat > "$INST/lead/questions.md" <<'EOF'
# questions.md — grill question bank (placeholder)
- What is the blast radius if this ships half-done?
- Which existing pattern should this follow, and is it current or deprecated?
- What must be true for this to be "done"?
- Is there a simpler version that still covers the need?
EOF

export TL_HOME="$INST" TL_DATA="$INST/data" TL_STATE="$INST/state" TL_WORKTREES="$INST/state/wt"
export TL_WORKER_CMD="$REPO/adapters/opencode-worker.sh"
export TL_GRILL_CMD="$REPO/adapters/opencode-grill.sh"
export TL_OPENCODE_MODEL="$MODEL"
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT

# target project: hello() present, farewell() missing; test flags what's missing
mkdir -p "$PROJ/tools"
printf '#!/bin/sh\nhello() { echo "hello, $1"; }\n' > "$PROJ/greet.sh"
cat > "$PROJ/tools/test.sh" <<'EOF'
#!/bin/sh
grep -q 'hello()' greet.sh || echo missing-hello
grep -q 'farewell()' greet.sh || echo missing-farewell
exit 0
EOF
chmod +x "$PROJ/tools/test.sh"
git -C "$PROJ" init -q -b main
git -C "$PROJ" add -A && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init

"$BIN/tl-project.sh" set greet path "$PROJ"
"$BIN/tl-project.sh" set greet mode local-only
"$BIN/tl-project.sh" set greet default_branch main
"$BIN/tl-project.sh" set greet readiness ready
"$BIN/tl-project.sh" set greet test_command "sh tools/test.sh"
"$BIN/tl-project.sh" set greet max_files_changed 5
"$BIN/tl-baseline.sh" greet

cat > "$INST/data/backlog.md" <<'EOF'
# Backlog

## add-farewell: Add a farewell function to greet.sh
greet.sh has hello() but no farewell(). Add farewell(name) echoing "goodbye, <name>",
matching the existing one-liner style. Small, self-contained.
EOF

echo "== grill (live inference) =="
"$BIN/tl-grill.sh" add-farewell
ID=tl-add-farewell
# owner answers any question the model left open, so the brief can proceed
for q in $("$BIN/tl-spec.sh" qlist "$ID" | awk -F'|' '$2=="open"{print $1}'); do
  "$BIN/tl-grill.sh" answer "$ID" "$q" decided "resolved for test"
done
[ "$("$BIN/tl-spec.sh" get "$ID" state)" = specified ] || fail "spec not specified after answering the delta"

echo "== brief =="
"$BIN/tl-brief.sh" "$ID"

echo "== spawn live worker (change) =="
"$BIN/tl-spawn.sh" --id live-1 --project "$PROJ" --project-name greet --kind change --brief "$INST/data/$ID/brief.md"

echo "== wait for the worker (up to ~8 min) =="
i=0; while [ $i -lt 160 ]; do [ -s "$INST/data/live-1/report.md" ] && break; sleep 3; i=$((i + 1)); done
[ -s "$INST/data/live-1/report.md" ] || fail "worker produced no report (model too slow, or errored)"
[ "$("$BIN/tl-state.sh" live-1)" = done ] || fail "worker did not reach done"

echo "== gate + deliver =="
TL_APPROVE=yes "$BIN/tl-deliver.sh" live-1

echo "== assert the change landed on main =="
git -C "$PROJ" show main:greet.sh | grep -q 'farewell' || fail "farewell function not on main"

echo "PASS: live opencode+$MODEL — backlog → grill → brief → worker → gate → ff-merge; farewell landed on main"
