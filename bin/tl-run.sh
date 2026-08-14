#!/usr/bin/env bash
# tl-run.sh — thin pipeline driver (§2.3, §2.4). Walks ONE backlog item grill → brief → spawn →
# gate/deliver by calling the existing tl-* commands, stopping at exactly the two points where the
# owner's judgment decides the outcome:
#   1. spec approval / reject  — halts if any question is `open` or the lead rejected the item
#   2. gate findings           — halts (via tl-deliver) while any `ask-user` finding is unresolved
# Everything between/after those is deterministic and runs without prompting.
#
# It holds NO authoritative state of its own: the current stage is RECOMPUTED every invocation from
# files (spec/brief/meta) + tl-state + findings. So it is killable and resumable — re-running it, or
# falling back to the individual tl-* commands, continues from wherever the pipeline actually is.
# After spawning it hands supervision to tl-watch and RETURNS — it never babysits the worker, and it
# never auto-answers an open question or auto-resolves a finding.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
slugify() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'; }

[ "${1:-}" = resume ] && shift          # `tl-run resume <slug>` == `tl-run <slug>` (always resumable)
slug="${1:?usage: tl-run [resume] <backlog-slug>}"
id="tl-$(slugify "$slug")"
count_q() { "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' -v k="$1" '$3==k{c++} END{print c+0}'; }

# ---- stage: grill (create the spec if it does not exist yet, or resume an interrupted pass) ----
# Resumability: re-grill not only when the spec is absent, but also when it exists yet the grill
# never finalized — a `drafted` spec with 0 open questions. _finalize sets `specified` (0 open) or
# `drafted` *with* the open deltas (open > 0), so "drafted AND 0 open" can only mean the driver died
# before _finalize (e.g. TL_GRILL_CMD unset on the first run). Without this, that wedges tl-run: the
# spec file exists so the grill is skipped forever, breaking the "just re-run tl-run" promise.
spec="$("$BIN/tl-spec.sh" path "$id")"
regrill=0
if [ ! -f "$spec" ]; then regrill=1
elif [ "$("$BIN/tl-spec.sh" get "$id" state 2>/dev/null || echo unknown)" = drafted ] \
  && [ "$("$BIN/tl-spec.sh" open-count "$id" 2>/dev/null || echo 0)" -eq 0 ]; then regrill=1
fi
if [ "$regrill" -eq 1 ]; then tl_log "run[$id]: grill"; "$BIN/tl-grill.sh" "$slug"; fi

# ---- STOP 1: spec approval / reject (owner judgment — never auto-answered) ----
state="$("$BIN/tl-spec.sh" get "$id" state 2>/dev/null || echo unknown)"
case "$state" in
  rejected)
    echo "tl-run: STOP — '$id' was rejected; nothing dispatched."
    awk 'f{print} /^## Rejected/{f=1}' "$spec" | sed 's/^/  /'
    exit 0 ;;
  specified) : ;;   # zero open questions → auto-advance (owner may still inspect the spec below)
  *)
    echo "tl-run: STOP — spec '$id' is '$state' with $("$BIN/tl-spec.sh" open-count "$id") open question(s); not dispatching."
    "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '$2=="open"{printf "  open [%s] %s\n",$1,$5}'
    echo "  answer:  tl-grill answer $id <qid> <decided|leaning|spike> [text]"
    echo "  or:      tl-grill reject $id <reason>"
    echo "  then:    tl-run $slug"
    exit 0 ;;
esac
echo "tl-run: spec '$id' specified — $(count_q inferred) inferred, $(count_q owner) owner-answered, 0 open"
echo "        ($spec)"

# ---- stage: brief (deterministic) ----
brief="$TL_DATA/$id/brief.md"
if [ ! -f "$brief" ]; then tl_log "run[$id]: brief"; "$BIN/tl-brief.sh" "$id"; fi

# ---- stage: spawn (deterministic; Part A resolves project/kind/brief), then HAND OFF and return ----
# tl: tl-run takes only a slug, so it leans on tl-spawn to resolve the project — the sole registered
#     one, or the spec's `project` field. On a multi-project instance, pin it first
#     (tl-spec set "$id" project NAME) or the spawn refuses naming the missing piece; add a
#     `tl-run --project NAME` passthrough if managing several projects at once becomes common.
if [ ! -f "$(tl_meta_file "$id")" ]; then
  tl_log "run[$id]: spawn"
  "$BIN/tl-spawn.sh" "$id"
  echo "tl-run: dispatched '$id' and left it supervised — do NOT babysit the worker."
  echo "  supervise: tl-watch            (or 'tl-watch --once'; it wakes you when the task is ready)"
  echo "  resume:    tl-run $slug        (re-run once the worker reaches 'done' → gate/deliver)"
  exit 0
fi

# ---- stage: supervise (recompute worker state from tl-state; never block) ----
st="$("$BIN/tl-state.sh" "$id")"
case "$st" in
  working)
    echo "tl-run: '$id' still working (tl-state=working) — supervise with tl-watch; re-run 'tl-run $slug' when done."
    exit 0 ;;
  failed)
    echo "tl-run: STOP — worker '$id' failed."
    "$BIN/tl-peek.sh" "$id" 20 2>/dev/null | sed 's/^/  /' || true
    exit 1 ;;
  done) : ;;
  *) echo "tl-run: '$id' state=$st — nothing to do."; exit 0 ;;
esac

# already delivered? (idempotent re-run)
delivered="$(tl_meta_get "$id" delivered 2>/dev/null || true)"
[ -n "$delivered" ] && { echo "tl-run: '$id' already delivered ($delivered)."; exit 0; }

# ---- stage: gate/deliver (change) or approve (plan) ----
kind="$(tl_meta_get "$id" kind)"
if [ "$kind" = change ]; then
  # STOP 2: tl-deliver runs the gate; it resolves findings (owner: approve/skip/fix) then ff-merges,
  # or refuses while any finding is unresolved. tl-run does not set TL_APPROVE — it never auto-resolves.
  echo "tl-run: gate + deliver '$id' — resolve any findings (approve / skip / fix)."
  if "$BIN/tl-deliver.sh" "$id"; then
    echo "tl-run: delivered '$id'."
  else
    echo "tl-run: STOP — delivery halted for '$id' (unresolved gate findings, or not fast-forwardable)."
    echo "  findings: $TL_DATA/$id/findings.json"
    echo "  resolve, then re-run: tl-run $slug"
    exit 3
  fi
else
  # plan: the terminal step is the owner approving the report — a decision point, never auto-run.
  echo "tl-run: STOP — plan report for '$id' is ready for review."
  echo "  report:  $(tl_meta_get "$id" report)"
  echo "  approve: tl-approve $id        (tl-run does not auto-approve)"
  exit 0
fi
