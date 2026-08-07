#!/usr/bin/env bash
# tl-shortcut.sh — the tl: annotated-shortcut detector (§3.13, E8.5 / #57). Workers mark deliberate
# simplifications with a `tl:` comment that names a CEILING and an UPGRADE PATH. This detector scans the
# ADDED lines of a change and emits two findings, folded into the gate and classified by the rubric:
#   - tl-shortcut-danger    : a tl: shortcut on a danger_path — an ask-user finding, never accepted (qi5)
#   - tl-shortcut-malformed : a tl: comment that names no upgrade path (§3.13's required form)
# Pure bash, no LLM. Output: rule<TAB>detail<TAB>path per finding.
set -euf   # -f: danger_paths are case-patterns; never pathname-expand them against the CWD
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-shortcut ID}"
wt="$(tl_meta_get "$id" worktree)"; base="$(tl_meta_get "$id" base)"; pname="$(tl_meta_get "$id" pname)"
danger="$("$BIN/tl-project.sh" get "$pname" danger_paths 2>/dev/null || true)"
changed="$(git -C "$wt" diff --name-only "$base"..HEAD 2>/dev/null || true)"

# A well-formed tl: names an upgrade path: an em-dash/`--` ceiling→path split, a conditional
# (if/when/until/once/unless), or a "use <X>" instruction. Anything else is a bare, unqualified shortcut.
UPGRADE='(—|--| if | when | until | once | unless |use )'

for f in $changed; do
  added="$(git -C "$wt" diff "$base"..HEAD -- "$f" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E 'tl:' || true)"
  [ -n "$added" ] || continue
  is_danger=0; for g in $danger; do case "$f" in $g) is_danger=1;; esac; done
  printf '%s\n' "$added" | while IFS= read -r line; do
    text="$(printf '%s' "${line#+}" | sed 's/^[[:space:]]*//')"
    case "$text" in *tl:*) ;; *) continue;; esac
    snip="$(printf '%s' "$text" | cut -c1-70)"
    if ! printf '%s' "$text" | grep -qE "tl:.+$UPGRADE"; then
      printf 'tl-shortcut-malformed\ttl: names no upgrade path: %s\t%s\n' "$snip" "$f"
    fi
    if [ "$is_danger" = 1 ]; then
      printf 'tl-shortcut-danger\ttl: shortcut on danger path %s: %s\t%s\n' "$f" "$snip" "$f"
    fi
  done
done
exit 0
