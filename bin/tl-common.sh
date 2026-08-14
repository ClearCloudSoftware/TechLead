#!/usr/bin/env bash
# tl-common.sh — shared helpers, sourced by every bin/tl-*.sh.
#
# Capability guard (§3.9): refuse to operate unless TL_HOME marks a real instance.
# This is capability removal, not a prompt instruction — an agent in some other checkout
# cannot reach the fleet just by wanting to; the entry point exits first.

if [ -z "${TL_HOME:-}" ]; then
  echo "tl: refusing — TL_HOME is not set (capability guard, §3.9)" >&2
  exit 78
fi
if [ ! -f "$TL_HOME/AGENTS.md" ]; then
  echo "tl: refusing — TL_HOME ($TL_HOME) is not a TechLead instance (no AGENTS.md)" >&2
  exit 78
fi

# Instance config (§3.2, E11/W1): load once so the operator sets harness/model/adapters in one
# place instead of every shell. The file (written by tl-init, single owner) uses conditional
# assignments — `export X="${X:-val}"` — so anything already set in the shell wins over the file.
# Absent file is a silent no-op. tl-init writes to this same path.
TL_CONFIG="${TL_CONFIG:-$TL_HOME/config/instance.env}"; export TL_CONFIG
[ -f "$TL_CONFIG" ] && . "$TL_CONFIG"

# Per-project state (owner decision 2026-08-14): data/state/lead live in <project>/.techlead, NOT
# in TL_HOME. TL_HOME is the tool install (bin/, adapters/, AGENTS.md, config); every managed repo
# keeps its own working state beside its code — the same convention as .claude/ and .superpowers/.
# Resolution is "nearest ancestor wins": walk up from $PWD to the closest .techlead/ (so being *in*
# a project is what selects it — no multi-project ambiguity). Outside any project (e.g. tl-init) we
# fall back to TL_HOME so tool-level commands still work. An already-exported TL_DATA/TL_STATE/TL_LEAD
# wins over resolution — tl-new/tl-onboard use that to target the project they are creating.
tl__find_root() {   # echoes the nearest ancestor .techlead dir, or non-zero if none
  d="$PWD"
  while [ "$d" != / ]; do
    [ -d "$d/.techlead" ] && { printf '%s\n' "$d/.techlead"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}
TL_ROOT="$(tl__find_root || echo "$TL_HOME")"
TL_DATA="${TL_DATA:-$TL_ROOT/data}"
TL_STATE="${TL_STATE:-$TL_ROOT/state}"
TL_LEAD="${TL_LEAD:-$TL_ROOT/lead}"        # judgment layer, per-project (single owner of the path)
TL_WORKTREES="${TL_WORKTREES:-$TL_STATE/wt}"
mkdir -p "$TL_DATA" "$TL_STATE" "$TL_WORKTREES"
export TL_HOME TL_DATA TL_STATE TL_LEAD TL_WORKTREES   # so a spawned worker inherits its instance

tl_log() { printf 'tl: %s\n' "$*" >&2; }
tl_die() { printf 'tl: %s\n' "$1" >&2; exit "${2:-1}"; }

# bump_hits <lead-file> <ordinal>...  — increment `hits:` and stamp `last:` on the Nth `### ` entry
# (1-indexed in file order — the same numbering the grill/review adapter shows the model). The reuse
# counter is the risk-1 / D13 signal (§2.6, SHAPE.md): a question fires on a grill, a rubric rule fires
# on a review. Out-of-range ordinals simply don't match, so a garbled ref is a silent no-op. Single
# owner of the hits: write, shared by tl-grill (questions.md) and tl-standards (review-rubric.md).
bump_hits() {
  local file="$1"; shift
  [ -f "$file" ] || return 0
  local ords date tmp
  ords=" $* "; date="$(date -u +%Y-%m-%d)"; tmp="$(mktemp)"
  awk -v ords="$ords" -v date="$date" '
    /^### /{ sec++ }
    /^hits:/ && index(ords, " " sec " ") > 0 {
      sub(/hits:[[:space:]]*[0-9]+/, "hits: " ($2 + 1))
      sub(/last:[[:space:]]*[^[:space:]].*/, "last: " date)
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Harness visibility (§2.7, §3.11): a worker's worktree branches from HEAD and the gate runs there too,
# so anything UNCOMMITTED in the project — most painfully the test harness — is invisible to both. The
# baseline (run against the working tree) then measures something the worker/gate never see. Warn at the
# chokepoints so that fails loud instead of silently. Returns 0 if clean, 1 if it warned.
tl_warn_uncommitted() { # <repo-path> <trailing advice>
  local repo="$1" advice="${2:-}" dirty
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null)" || return 0   # not a git repo → nothing to check
  [ -n "$dirty" ] || return 0
  tl_log "⚠ uncommitted changes in $repo — a worker branches from HEAD (and the gate runs there), so"
  tl_log "  these are INVISIBLE to it, including your test harness. $advice"
  printf '%s\n' "$dirty" | sed 's/^/    /' >&2
  return 1
}

# Seed the lead/ file skeleton — the E6.2/§2.4 SHAPE only, never borrowed judgment (lead/README is
# explicit that principles must accrete from real grills). Per-project now (owner decision
# 2026-08-14): each managed repo grows its own judgment. Existing files are left untouched.
tl_seed_lead() { # <lead-dir>
  local L="$1"; mkdir -p "$L/decisions"
  [ -e "$L/decisions/.gitkeep" ] || : > "$L/decisions/.gitkeep"
  local f
  for f in principles review-rubric delegation escalation questions voice; do
    [ -f "$L/$f.md" ] && continue
    printf '# %s\n\n<!-- stub (tl-scaffold). Shape: lead/SHAPE.md. Fill from real grills; do not seed borrowed judgment (lead/README). -->\n' "$f" > "$L/$f.md"
  done
}

# Create <root>/.techlead/{data,state,lead} for a managed repo and keep it out of the repo's history
# (like .claude/.superpowers — private working state, not source). Single owner of the .techlead shape.
tl_scaffold_project() { # <project-root>
  local root="$1" th="$1/.techlead"
  mkdir -p "$th/data/projects" "$th/state" "$th/lead"
  tl_seed_lead "$th/lead"
  if [ -d "$root/.git" ] && ! grep -qxF '.techlead/' "$root/.gitignore" 2>/dev/null; then
    printf '.techlead/\n' >> "$root/.gitignore"
  fi
}

# task metadata — one key=value per line in state/<id>.meta (§3.2). Single owner of task state.
tl_meta_file() { printf '%s/%s.meta' "$TL_STATE" "$1"; }
tl_meta_get() { # id key -> value on stdout; non-zero if the file is missing
  [ -f "$(tl_meta_file "$1")" ] || return 1
  awk -v k="$2" 'index($0,k"=")==1{sub(/^[^=]*=/,"");print;exit}' "$(tl_meta_file "$1")"
}
tl_meta_set() { # id key value  (rewrite so last value wins on read — not an event log)
  local f tmp; f="$(tl_meta_file "$1")"; tmp="$(mktemp)"
  { [ -f "$f" ] && grep -v "^$2=" "$f" || true; printf '%s=%s\n' "$2" "$3"; } > "$tmp"
  mv "$tmp" "$f"
}

# tl_current_project — the sole project registered in the current .techlead (per-project state means one
# per repo). Lets commands run from inside a project default the <name> arg instead of retyping it.
# Non-zero if zero or more-than-one are registered (caller then requires an explicit name).
tl_current_project() {
  local d="$TL_DATA/projects" n=0 sole="" c
  [ -d "$d" ] || return 1
  for c in "$d"/*.conf; do [ -f "$c" ] || continue; n=$((n+1)); sole="$(basename "$c" .conf)"; done
  [ "$n" -eq 1 ] || return 1
  printf '%s\n' "$sole"
}

tl_now() { date +%s; }
tl_mtime() { stat -f %m "$1" 2>/dev/null || echo 0; }   # tl: macOS BSD stat — `stat -c %Y` on GNU

# APPEND-ONLY event log (§3.4). Workers append only wake-worthy transitions; nothing on silent
# resume. tl_status_last returns the last *event's* verb — a hint for tl-state to reconcile, NOT
# the current state. Read current state through bin/tl-state.sh, never this tail.
tl_status_file() { printf '%s/%s.status' "$TL_STATE" "$1"; }
tl_status_last() { tail -n 1 "$(tl_status_file "$1")" 2>/dev/null | awk -F'\t' '{print $2}'; }
