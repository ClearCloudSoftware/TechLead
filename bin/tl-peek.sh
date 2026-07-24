#!/usr/bin/env bash
# tl-peek.sh — non-invasively show a worker's recent output (§3.5 layer, read-only).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-session.sh"
id="${1:?usage: tl-peek ID [lines]}"
tl_session_peek "$id" "${2:-40}"
