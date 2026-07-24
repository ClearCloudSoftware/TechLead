#!/usr/bin/env bash
# tl-project.sh — single owner of per-project registry reads (§3.12). Each managed repo is a
# key=value config under data/projects/<name>.conf, parsed structurally, never free-text.
# Realises §3.12's registry as one file per project (single-owner per project) for Phase 0.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
CFGDIR="$TL_DATA/projects"; mkdir -p "$CFGDIR"

cmd="${1:?usage: tl-project get|set|path <name> [key] [value]}"; name="${2:?name}"; cfg="$CFGDIR/$name.conf"
case "$cmd" in
  set)  key="${3:?key}"; val="${4-}"; tmp="$(mktemp)"
        { [ -f "$cfg" ] && grep -v "^$key=" "$cfg" || true; printf '%s=%s\n' "$key" "$val"; } > "$tmp"; mv "$tmp" "$cfg" ;;
  get)  key="${3:?key}"; [ -f "$cfg" ] || exit 1
        awk -F= -v k="$key" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$cfg" ;;
  path) echo "$cfg" ;;
  *)    tl_die "usage: tl-project get|set|path <name> [key] [value]" ;;
esac
