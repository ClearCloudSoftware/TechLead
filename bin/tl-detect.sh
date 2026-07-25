#!/usr/bin/env bash
# tl-detect.sh — best-effort defaults for the onboarding wizard (§2.7, E11/W4). Each subcommand
# inspects a target repo and prints ONE suggested default, or nothing when it can't tell — so the
# wizard falls open to asking plainly rather than committing a wrong guess. Mechanics only: it reads
# the repo, it never writes the registry.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"

cmd="${1:?usage: tl-detect mode|branch|test-command|danger-paths <path>}"
path="${2:?path}"
[ -d "$path" ] || tl_die "no such directory: $path"

case "$cmd" in
  mode)    # a git remote implies a shared repo -> open a PR; otherwise fast-forward locally
    [ -n "$(git -C "$path" remote 2>/dev/null)" ] && echo pr || echo local-only ;;
  branch)  # current branch (resolves an unborn branch too, e.g. a fresh `git init -b main`)
    git -C "$path" symbolic-ref --short -q HEAD 2>/dev/null || true ;;
  test-command)  # first recognised harness wins; empty if none (wizard then asks plainly)
    if   [ -f "$path/package.json" ] && grep -q '"test"[[:space:]]*:' "$path/package.json"; then echo "npm test"
    elif [ -f "$path/Makefile" ]    && grep -Eq '^test:' "$path/Makefile";                 then echo "make test"
    elif [ -f "$path/Cargo.toml" ];                                                         then echo "cargo test"
    elif [ -f "$path/go.mod" ];                                                             then echo "go test ./..."
    elif [ -f "$path/pytest.ini" ] || [ -f "$path/tox.ini" ] \
         || ls "$path"/*_test.py >/dev/null 2>&1 || ls "$path"/test_*.py >/dev/null 2>&1 \
         || { [ -f "$path/pyproject.toml" ] && grep -q pytest "$path/pyproject.toml"; };    then echo "pytest -q"
    fi ;;
  danger-paths)  # suggest the risky globs that actually exist in this tree; empty if none
    out=""
    for g in migrations .github secrets; do [ -e "$path/$g" ] && out="$out $g/**"; done
    echo "${out# }" ;;
  *) tl_die "unknown detector: $cmd (want mode|branch|test-command|danger-paths)" ;;
esac
