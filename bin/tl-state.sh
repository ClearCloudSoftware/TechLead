#!/usr/bin/env bash
# tl-state.sh — the SINGLE OWNER of current-state reads (§3.4). The most important mechanism here,
# and the one most likely to be reinvented badly.
#
# It never trusts the event-log tail. It reconciles the possibly-stale log against authoritative
# signals (§3.5): the session's liveness (layer 1 — process exit is the headless turn-end signal),
# and OS activity (layer 2 — worktree/log mtime). A worker that resumed after an escalation leaves
# its log tail reading `needs-decision` forever; this script still reports `working`/`done`.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-session.sh"
id="${1:?usage: tl-state ID}"
[ -f "$(tl_meta_file "$id")" ] || { echo unknown; exit 0; }

report="$(tl_meta_get "$id" report 2>/dev/null || true)"
last="$(tl_status_last "$id" 2>/dev/null || true)"    # last EVENT verb — a hint, not the truth
sess_log="$TL_STATE/sessions/$id/log"
FRESH="${TL_FRESH_SECS:-5}"

if tl_session_alive "$id"; then
  case "$last" in
    blocked|needs-decision|paused|paused:*)
      # the log says stuck — but fresh OS activity means it silently resumed (§3.4). Truth wins.
      age=$(( $(tl_now) - $(tl_mtime "$sess_log") ))
      if [ "$age" -lt "$FRESH" ]; then echo working; else echo "$last"; fi
      ;;
    *) echo working ;;
  esac
else
  # session ended = turn ended (headless: process exit is the layer-1 turn-end signal, §3.5).
  # Reconcile against the deliverable, NOT the log tail — which may still read `needs-decision`.
  if [ -n "$report" ] && [ -s "$report" ]; then echo done; else echo failed; fi
fi
