#!/usr/bin/env bash
# tl-top-smoke.sh — unit-check tl-top's pure fleet-model builder (no terminal, no agent,
# zero tokens). A curses UI can't be driven headless, so the design splits the logic out:
# build_fleet_model is pure and asserted here via `tl-top --selftest`.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$here/../bin/tl-top" --selftest
