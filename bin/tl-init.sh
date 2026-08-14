#!/usr/bin/env bash
# tl-init.sh — instance setup wizard (§3.2, E11/W2). COLLECTS the operator's choices (harness, model,
# projects dir, whether to seed lead/) and writes them to config/instance.env, which tl-common loads
# (W1). Orchestrator, not owner: it configures the instance; it never becomes authoritative state.
# Reuses the stated-default prompt idiom (tl-escalate) via tl-wizard.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

for a in "$@"; do case "$a" in
  --yes|-y) TL_YES=1;;
  -h|--help) echo "usage: tl-init [--yes]   (non-interactive: --yes or TL_ANSWER_* env)"; exit 0;;
  *) tl_die "unknown arg: $a";;
esac; done

harness="$(tl_choose HARNESS "coding harness" "claude" claude opencode)"
case "$harness" in
  claude)   worker="$TL_HOME/adapters/claude-worker.sh";   grill="$TL_HOME/adapters/claude-grill.sh"
            propose="$TL_HOME/adapters/claude-grill-propose.sh"; model="";;
  opencode) worker="$TL_HOME/adapters/opencode-worker.sh"; grill="$TL_HOME/adapters/opencode-grill.sh"
            propose=""   # no opencode proposer yet → propose-mode falls back to the seed-by-hand message
            model="$(tl_ask MODEL "opencode model (must support tools)" "ollama/qwen3-coder:30b")";;
  *) tl_die "unknown harness: $harness (want claude|opencode)";;
esac
# NB: no projects-dir prompt — tl-new creates in the current directory. Set TL_PROJECTS_DIR in your
# shell only if you want a fixed home for every new project (rare); tl-init does not bake it in.

# Single owner of config/instance.env. Conditional assignments => a var already set in the shell
# wins over the file (the W1 contract). tl-common reads back from this same $TL_CONFIG.
mkdir -p "$(dirname "$TL_CONFIG")"
{
  echo "# TechLead instance config — written by tl-init on $(date -u +%Y-%m-%d). Re-run tl-init to change."
  echo "# Conditional assignments: anything already exported in your shell wins over this file."
  printf 'export TL_WORKER_CMD="${TL_WORKER_CMD:-%s}"\n' "$worker"
  printf 'export TL_GRILL_CMD="${TL_GRILL_CMD:-%s}"\n' "$grill"
  [ -n "$propose" ] && printf 'export TL_GRILL_PROPOSE_CMD="${TL_GRILL_PROPOSE_CMD:-%s}"\n' "$propose"
  [ -n "$model" ] && printf 'export TL_OPENCODE_MODEL="${TL_OPENCODE_MODEL:-%s}"\n' "$model"
} > "$TL_CONFIG"
tl_log "wrote $TL_CONFIG"

# NB: lead/ is no longer seeded here — it is per-project now (owner decision 2026-08-14). tl-new and
# tl-onboard scaffold each managed repo's own <project>/.techlead/lead skeleton. tl-init configures
# the tool only; it never becomes authoritative state.

printf 'tl: instance configured (harness=%s)\n' "$harness" >&2
printf 'tl: next → register an existing repo: tl-onboard <path>   |   create a new one: tl-new <name>\n' >&2
