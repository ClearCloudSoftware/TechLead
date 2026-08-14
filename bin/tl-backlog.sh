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
    # the title is one markdown heading line — a newline (e.g. a mis-pasted multi-line arg) would split
    # the heading and orphan its tail. Reject it loudly rather than write a broken item.
    [ "$(printf '%s' "$title" | wc -l | tr -d ' ')" -eq 0 ] \
      || tl_die "title must be a single line (it contains a newline) — quote the whole title on one line"
    desc="$*"
    if [ ! -f "$BACKLOG" ]; then
      mkdir -p "$(dirname "$BACKLOG")"; printf '# Backlog\n' > "$BACKLOG"
    elif ! grep -q '^# ' "$BACKLOG"; then
      # existing but header-less (created by hand or an earlier flow) — restore the H1 so it's well-formed
      { printf '# Backlog\n\n'; cat "$BACKLOG"; } > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
    fi
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
  show)
    # show <slug> — the READ side of one item: "<line>\t<title>" then the body verbatim. Same heading
    # rule `add` writes and tl-grill matches, in one place, so a reader (tl-top) doesn't grow a second
    # copy of the awk (§3.1 single owner). The line number is what `$EDITOR +<line>` needs.
    slug="${2:?usage: tl-backlog show <slug>}"
    [ -f "$BACKLOG" ] || tl_die "no backlog at $BACKLOG (add one: tl-backlog add <slug> \"<title>\")"
    out="$(awk -v s="$slug" '
      index($0,"## "s":")==1 { t=$0; sub("^## [^:]*: *","",t); printf "%d\t%s\n", NR, t; f=1; next }
      f && index($0,"## ")==1 { exit }
      f { print }' "$BACKLOG")"
    [ -n "$out" ] || tl_die "backlog item '$slug' not found in $BACKLOG"
    printf '%s\n' "$out"
    ;;
  -h|--help)
    echo 'usage: tl-backlog add <slug> "<title>" [description...]   |   tl-backlog list   |   tl-backlog show <slug>'; exit 0 ;;
  *)
    tl_die 'usage: tl-backlog add <slug> "<title>" [description...] | list | show <slug>' ;;
esac
