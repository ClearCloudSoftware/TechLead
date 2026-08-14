#!/usr/bin/env bash
# tl-peek.sh — non-invasively show a worker's recent output (§3.5 layer, read-only).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-session.sh"; . "$BIN/tl-wizard.sh"
id="${1:-$(tl_pick_task || true)}"          # no id at a terminal -> fuzzy-pick from the live fleet
[ -n "$id" ] || tl_die "usage: tl-peek ID [lines]"
tl_session_peek "$id" "${2:-40}"
