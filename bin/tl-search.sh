#!/usr/bin/env bash
# tl-search.sh — the ONLY file that knows the code-graph tool (Graphify) exists. A seam per §3.11,
# exactly like tl-worktree.sh: a small, stable interface in, a compact result out. Grill, review,
# worker briefs, and the onboarding survey call tl-search — never graphify directly. Swap the tool
# here and nowhere else.
#
# BOUNDARY — do not blur (the agentmemory/Paperclip line, again): the graph is CODEBASE MEMORY, a
# better map of *the code*. It is NOT lead/, which is the owner's authored *judgment* about the code.
# Graph artifacts (and graphify's own memory/) describe the code; lead/ describes the owner. Never
# feed graph output into lead/.
#
# tl: graphify has no out-of-tree *no-LLM* build — `extract --out` needs an LLM API key (semantic),
# tl: and no-LLM `update` writes graphify-out/ INTO the tree it scans (no --out). So `ast` mode scans
# tl: a throwaway `git archive` export, never the live repo, then relocates the result. Collapse the
# tl: export away if graphify ever grows `update --out`.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"

cmd="${1:?usage: tl-search build|refresh|query|explain|path|status <project> [args...]}"
name="${2:?project name}"; shift 2 || true

pj() { "$BIN/tl-project.sh" "$@"; }
mode="$(pj get "$name" graph_mode 2>/dev/null || echo off)"; [ -n "$mode" ] || mode=off
path="$(pj get "$name" path 2>/dev/null || true)"
# Graph artifacts live under gitignored /data/ (§3.16): never committed, never in a worker worktree,
# never loaded into the prompt prefix — only queried through this seam, which returns a projection.
graphdir="$TL_DATA/projects/$name.graph"
graphjson="$graphdir/graphify-out/graph.json"
budget="${TL_SEARCH_BUDGET:-2000}"
have() { command -v graphify >/dev/null 2>&1; }

# EXIT 3 = "no graph available — fall back to grep" (distinct from a real failure), so a caller can
# branch on it instead of treating a missing graph as an error.
_build_ast() {   # no-LLM: scan a git export so graphify never writes into the managed repo
  local tmp; tmp="$(mktemp -d)"
  git -C "$path" archive HEAD 2>/dev/null | tar -x -C "$tmp" 2>/dev/null \
    || { rm -rf "$tmp"; tl_die "git archive HEAD failed for '$name' ($path) — is there a commit?"; }
  graphify update "$tmp" >&2 || { rm -rf "$tmp"; tl_die "graphify update failed for '$name'"; }
  [ -f "$tmp/graphify-out/graph.json" ] || { rm -rf "$tmp"; tl_die "graphify produced no graph for '$name'"; }
  rm -rf "$graphdir/graphify-out"; mkdir -p "$graphdir"
  mv "$tmp/graphify-out" "$graphdir/graphify-out" || { rm -rf "$tmp"; tl_die "could not relocate graph for '$name'"; }
  rm -rf "$tmp"
}
_build_semantic() {   # AST + semantic LLM; extract honours --out, so no export needed
  mkdir -p "$graphdir"
  graphify extract "$path" --out "$graphdir" >&2 \
    || tl_die "graphify extract failed for '$name' — semantic build needs an LLM API key (ANTHROPIC_API_KEY / MOONSHOT_API_KEY)"
}

case "$cmd" in
  build)
    [ "$mode" != off ] || tl_die "graph_mode=off for '$name' — enable it: tl-project set $name graph_mode ast|semantic (or re-run tl-onboard)"
    [ -n "$path" ] && [ -d "$path" ] || tl_die "no registered path for '$name'"
    have || tl_die "graphify not installed — cannot build a graph for '$name'" 3
    case "$mode" in
      ast)      _build_ast ;;
      semantic) _build_semantic ;;
      *)        tl_die "unknown graph_mode '$mode' for '$name' (want off|ast|semantic)" ;;
    esac
    [ -f "$graphjson" ] || tl_die "build produced no graph.json at $graphjson"
    pj set "$name" graph "$graphjson"
    pj set "$name" graph_at "$(date -u +%Y-%m-%d)"
    pj set "$name" graph_stale ""
    tl_log "graph built ($mode) for '$name' — $graphjson"
    ;;

  refresh)   # the refresh trigger: called on land of a change that touched the project. Cheap, fail-open.
    [ "$mode" != off ] || exit 0
    [ -f "$graphjson" ] || exit 0                 # never built yet — the survey builds it, not a land
    have || { tl_log "graphify absent — graph for '$name' not refreshed"; exit 0; }
    case "$mode" in
      ast) _build_ast; pj set "$name" graph_at "$(date -u +%Y-%m-%d)"; pj set "$name" graph_stale ""
           tl_log "graph refreshed (ast, no-LLM) for '$name'" ;;
      # A semantic re-extract costs LLM tokens — never auto-spend on every land. Mark the graph STALE,
      # loudly, so a later query knows the map trails the code (a silently-stale graph is worse than
      # none — the same failure mode as a stale test baseline).
      semantic) pj set "$name" graph_stale "$(date -u +%Y-%m-%d)"
           tl_log "semantic graph for '$name' now STALE — rebuild when worth it: tl-search build $name" ;;
    esac
    ;;

  query|explain|path)
    have || tl_die "graphify not installed — fall back to grep" 3
    [ -f "$graphjson" ] || tl_die "no graph for '$name' — build it (tl-search build $name) or grep" 3
    stale="$(pj get "$name" graph_stale 2>/dev/null || true)"
    [ -n "$stale" ] && tl_log "note: '$name' graph is STALE since $stale — rebuild: tl-search build $name"
    case "$cmd" in
      query)   graphify query   "${1:?usage: tl-search query $name \"<question>\"}" --graph "$graphjson" --budget "$budget" ;;
      explain) graphify explain  "${1:?usage: tl-search explain $name \"<symbol>\"}" --graph "$graphjson" ;;
      path)    graphify path     "${1:?usage: tl-search path $name \"A\" \"B\"}" "${2:?need two endpoints}" --graph "$graphjson" ;;
    esac
    ;;

  status)   # one compact line for a caller deciding graph-vs-grep: off | <mode> unbuilt | <mode> built=DATE [STALE=DATE]
    if [ "$mode" = off ]; then echo "off"
    elif [ -f "$graphjson" ]; then
      printf '%s\tbuilt=%s' "$mode" "$(pj get "$name" graph_at 2>/dev/null || echo '?')"
      stale="$(pj get "$name" graph_stale 2>/dev/null || true)"; [ -n "$stale" ] && printf '\tSTALE=%s' "$stale"
      printf '\n'
    else printf '%s\tunbuilt\n' "$mode"; fi
    ;;

  *) tl_die "usage: tl-search build|refresh|query|explain|path|status <project> [args...]" ;;
esac
