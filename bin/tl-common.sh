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

TL_DATA="${TL_DATA:-$TL_HOME/data}"
TL_STATE="${TL_STATE:-$TL_HOME/state}"
TL_WORKTREES="${TL_WORKTREES:-$TL_STATE/wt}"
mkdir -p "$TL_DATA" "$TL_STATE" "$TL_WORKTREES"
export TL_HOME TL_DATA TL_STATE TL_WORKTREES   # so a spawned worker inherits its instance

tl_log() { printf 'tl: %s\n' "$*" >&2; }
tl_die() { printf 'tl: %s\n' "$1" >&2; exit "${2:-1}"; }

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

tl_now() { date +%s; }
tl_mtime() { stat -f %m "$1" 2>/dev/null || echo 0; }   # tl: macOS BSD stat — `stat -c %Y` on GNU

# APPEND-ONLY event log (§3.4). Workers append only wake-worthy transitions; nothing on silent
# resume. tl_status_last returns the last *event's* verb — a hint for tl-state to reconcile, NOT
# the current state. Read current state through bin/tl-state.sh, never this tail.
tl_status_file() { printf '%s/%s.status' "$TL_STATE" "$1"; }
tl_status_last() { tail -n 1 "$(tl_status_file "$1")" 2>/dev/null | awk -F'\t' '{print $2}'; }
