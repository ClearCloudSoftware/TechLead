#!/usr/bin/env bash
# tl-session.sh — the session seam: a worker runs inside a "session"; peek/send/kill act on it.
# The design assumes a terminal multiplexer (tmux) so a pane can be tailed (§3.5) and keystrokes
# injected. This host has no tmux, and the plan tracer bullet needs neither, so back it with a
# background process + logfile for now. tmux/screen plugs into these same four functions later.
# tl: background-process session, no interactive inject — swap to tmux when change-workers land (§3.5)

. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/tl-common.sh"

_tl_sess_dir() { printf '%s/sessions/%s' "$TL_STATE" "$1"; }

tl_session_start() { # id workdir -- cmd [args...]
  local id="$1" workdir="$2"; shift 2; [ "${1:-}" = "--" ] && shift
  local d; d="$(_tl_sess_dir "$id")"; mkdir -p "$d"
  : > "$d/in"   # best-effort mailbox for tl_session_send
  ( cd "$workdir" && exec "$@" >"$d/log" 2>&1 ) &
  echo $! > "$d/pid"
}
tl_session_peek()  { tail -n "${2:-40}" "$(_tl_sess_dir "$1")/log" 2>/dev/null; }
tl_session_send()  { printf '%s\n' "$2" >> "$(_tl_sess_dir "$1")/in"; }  # interactive inject arrives with tmux
tl_session_alive() { local p; p="$(cat "$(_tl_sess_dir "$1")/pid" 2>/dev/null)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
tl_session_kill()  { local p; p="$(cat "$(_tl_sess_dir "$1")/pid" 2>/dev/null || true)"; if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then kill "$p" 2>/dev/null || true; fi; return 0; }
