#!/usr/bin/env bash
# tl-peek.sh — non-invasively show a worker's recent output (§3.5 layer, read-only).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-session.sh"
id="${1:?usage: tl-peek ID [lines] [-f|--follow]}"
lines="${2:-40}"
case "${3:-}" in
  -f|--follow)
    # Follow the session log until the reader interrupts. Watching a worker meant pressing peek
    # over and over; the session path belongs to tl-session, so the follow lives here rather than
    # in a caller re-deriving it (§3.1).
    exec tail -n "$lines" -f "$TL_STATE/sessions/$id/log" ;;
esac
tl_session_peek "$id" "$lines"
