#!/usr/bin/env bash
# tl-backlog.sh — the owner's entry point (§2.6) without hand-formatting headings. `add` appends one
# well-formed item (validated slug, no duplicate); `list` prints the items. The backlog stays a plain
# markdown file anyone can also edit directly — this is a convenience + a slug guard, not a new owner.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
BACKLOG="${TL_BACKLOG:-$TL_DATA/backlog.md}"

cmd="${1:-}"
case "$cmd" in
  add)
    slug="${2:?usage: tl-backlog add <slug> \"<title>\" [description...]}"; shift 2 || true
    # slug is bare/url-safe/lowercase — it becomes the task id (tl-<slug>) and branch (tl/tl-<slug>),
    # and tl-grill matches the heading literally, so uppercase or spaces would silently mis-resolve.
    case "$slug" in -*|*-) tl_die "slug must not start or end with '-' (got: $slug)";; esac
    # LC_ALL=C so a-z means ASCII lowercase — a UTF-8 collation makes case's [a-z] match uppercase too.
    if printf '%s' "$slug" | LC_ALL=C grep -q '[^a-z0-9-]'; then
      tl_die "slug must be lowercase letters, digits, hyphens — e.g. add-search (got: $slug)"
    fi
    title="${1:?usage: tl-backlog add <slug> \"<title>\" [description...]}"; shift || true
    desc="$*"
    [ -f "$BACKLOG" ] || { mkdir -p "$(dirname "$BACKLOG")"; printf '# Backlog\n' > "$BACKLOG"; }
    # refuse a duplicate slug — tl-grill matches the FIRST heading, so a second would be unreachable
    if awk -v s="$slug" 'index($0,"## "s":")==1{f=1} END{exit !f}' "$BACKLOG"; then
      tl_die "backlog already has an item '$slug' — pick another slug or edit $BACKLOG"
    fi
    {
      printf '\n## %s: %s\n' "$slug" "$title"
      if [ -n "$desc" ]; then printf '%s\n' "$desc"; fi
    } >> "$BACKLOG"
    tl_log "added '$slug' to $BACKLOG"
    printf 'tl: next → grill it:  tl-grill %s   (or tl-run %s for the whole pipeline)\n' "$slug" "$slug" >&2
    ;;
  list)
    [ -f "$BACKLOG" ] || tl_die "no backlog at $BACKLOG (add one: tl-backlog add <slug> \"<title>\")"
    awk '/^## /{sub(/^## /,""); print "  "$0}' "$BACKLOG"
    ;;
  -h|--help)
    echo 'usage: tl-backlog add <slug> "<title>" [description...]   |   tl-backlog list'; exit 0 ;;
  *)
    tl_die 'usage: tl-backlog add <slug> "<title>" [description...] | list' ;;
esac
