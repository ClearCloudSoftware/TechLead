#!/usr/bin/env bash
# tl-send.sh — inject a message/answer into a running worker's session (§2.3, §3.5).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-session.sh"
id="${1:?usage: tl-send ID MESSAGE...}"; shift
tl_session_send "$id" "$*"
