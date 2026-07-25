#!/usr/bin/env bash
# tl-spec.sh — single owner of spec.md structured reads/writes (§3.10). spec.md is the DURABLE
# what-&-why (it becomes the ADR). Machine fields live in its front matter; each question is one
# pipe-encoded line — qid|answer_state|source|answered_at|text — flat so bash parses it without a
# YAML library. tl: pipe-encoded questions, not nested YAML maps — Phase 0 bash-parseability;
# swap for real YAML if the spec grows structure.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
sub="${1:?usage: tl-spec init|get|set|qset|qlist|open-count|path ID ...}"; id="${2:?id}"
spec="$TL_DATA/$id/spec.md"

case "$sub" in
  path) echo "$spec" ;;
  init) # id slug title [bodyfile]
    slug="${3:?}"; title="${4:?}"; body="${5:-/dev/null}"; mkdir -p "$TL_DATA/$id"
    { printf -- '---\nid: %s\nbacklog: %s\ntitle: %s\nstate: drafted\ngrilled_at: %s\n---\n' \
        "$id" "$slug" "$title" "$(date -u +%Y-%m-%d)"
      printf '# %s\n\n_Backlog item:_ `%s`\n\n' "$title" "$slug"
      cat "$body" 2>/dev/null || true
    } > "$spec" ;;
  get) # field  -> value (front-matter scalar only)
    awk -v k="${3:?}" '/^---$/{n++;next} n==1 && $0 ~ "^"k": "{sub("^"k": ","");print;exit}' "$spec" ;;
  set) # field value  (replace in front matter, or insert before its close)
    k="${3:?}"; v="${4-}"; tmp="$(mktemp)"
    awk -v k="$k" -v v="$v" '
      /^---$/{ n++; if(n==2 && !d){print k": "v; d=1} print; next }
      n==1 && $0 ~ "^"k": " { if(!d){print k": "v; d=1}; next }
      {print}' "$spec" > "$tmp" && mv "$tmp" "$spec" ;;
  qset) # qid state source answered_at text  (upsert one question line)
    qid="${3:?}"; line="q: ${3}|${4:?}|${5:?}|${6:?}|${7:?}"; tmp="$(mktemp)"
    awk -v qid="$qid" -v line="$line" '
      /^---$/{ n++; if(n==2 && !d){print line; d=1} print; next }
      n==1 && $0 ~ "^q: "qid"\\|" { if(!d){print line; d=1}; next }
      {print}' "$spec" > "$tmp" && mv "$tmp" "$spec" ;;
  qlist)  awk '/^---$/{n++;next} n==1 && /^q: /{sub("^q: ","");print}' "$spec" ;;
  open-count)
    awk '/^---$/{n++;next} n==1 && /^q: /{sub("^q: ","");print}' "$spec" | awk -F'|' '$2=="open"{c++} END{print c+0}' ;;
  *) tl_die "unknown tl-spec subcommand: $sub" ;;
esac
