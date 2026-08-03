#!/usr/bin/env bash
# search-smoke.sh — the tl-search seam (code-graph search behind Graphify, §3.11). Drives it against
# a stub `graphify` on PATH (like demo-worker.sh stands in for a real coding agent) so the test is
# deterministic, offline, and spends zero tokens. Proves the load-bearing invariant: a graph build
# NEVER writes into the managed repo or its worktrees (§3.16 cache discipline) — it lands only under
# gitignored data/. Also proves fail-closed behaviour (absent tool / no graph → non-zero, caller greps).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }

WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
export TL_CONFIG="$WORK/config/instance.env" TL_YES=1
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT
SEARCH="$BIN/tl-search.sh"

# --- stub graphify on PATH: mimics the real tool's output *locations* so relocation logic is tested ---
STUB="$WORK/stub"; mkdir -p "$STUB"
cat > "$STUB/graphify" <<'STUBEOF'
#!/usr/bin/env bash
set -eu
cmd="${1:-}"; shift || true
_graph() { mkdir -p "$1/graphify-out"
  printf '{"nodes":[{"id":"foo","label":"foo","file":"a.py"},{"id":"bar","label":"bar","file":"b.py"}],"edges":[{"source":"foo","target":"bar","context":"calls"}]}\n' > "$1/graphify-out/graph.json"; }
case "$cmd" in
  update)  _graph "$1"; echo "[stub] update $1" >&2 ;;                      # writes INTO the scanned dir (as real update does)
  extract) p="$1"; shift; out="$p"; while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
           _graph "$out"; echo "[stub] extract $p -> $out" >&2 ;;           # honours --out (as real extract does)
  query)   echo "[stub-answer] query: $1" ;;
  explain) echo "[stub-answer] explain: $1" ;;
  path)    echo "[stub-answer] path: $1 :: $2" ;;
  *) echo "[stub] unknown: $cmd" >&2; exit 2 ;;
esac
STUBEOF
chmod +x "$STUB/graphify"
export PATH="$STUB:$PATH"

mkrepo() { # dir  — a tiny committed python repo
  mkdir -p "$1"; printf 'def foo():\n    return bar()\n' > "$1/a.py"; printf 'def bar():\n    return 1\n' > "$1/b.py"
  git -C "$1" init -q -b main
  git -C "$1" -c user.email=t@t -c user.name=t add -A
  git -C "$1" -c user.email=t@t -c user.name=t commit -q -m stub
}

echo "== D1: ast build lands out-of-tree, never in the managed repo (§3.16) =="
APP="$WORK/app"; mkrepo "$APP"
"$BIN/tl-project.sh" set app path "$(cd "$APP" && pwd -P)"
"$BIN/tl-project.sh" set app graph_mode ast
"$SEARCH" build app >/dev/null 2>&1 || fail "ast build failed"
GJSON="$TL_DATA/projects/app.graph/graphify-out/graph.json"
[ -f "$GJSON" ]                                  || fail "graph.json not at the out-of-tree home ($GJSON)"
[ ! -e "$APP/graphify-out" ]                     || fail "POLLUTION: graphify-out written into the managed repo ($APP)"
[ "$("$BIN/tl-project.sh" get app graph)" = "$GJSON" ] || fail "registry 'graph' not recorded"
[ -n "$("$BIN/tl-project.sh" get app graph_at)" ]      || fail "registry 'graph_at' not recorded"
echo "  ok — graph under data/ only; managed repo clean; registry updated"

echo "== D1: query/explain/path return the tool's answer on stdout =="
"$SEARCH" query   app "what calls bar" | grep -q 'query: what calls bar'  || fail "query did not pass through"
"$SEARCH" explain app "foo"            | grep -q 'explain: foo'           || fail "explain did not pass through"
"$SEARCH" path    app "foo" "bar"      | grep -q 'foo :: bar'            || fail "path did not pass through"
"$SEARCH" status  app | grep -q '^ast	built='                          || fail "status did not report a built ast graph"
echo "  ok — query/explain/path/status answer for a registered project"

echo "== semantic build uses extract --out (also out-of-tree) =="
APP2="$WORK/sem"; mkrepo "$APP2"
"$BIN/tl-project.sh" set sem path "$(cd "$APP2" && pwd -P)"
"$BIN/tl-project.sh" set sem graph_mode semantic
"$SEARCH" build sem >/dev/null 2>&1 || fail "semantic build failed"
[ -f "$TL_DATA/projects/sem.graph/graphify-out/graph.json" ] || fail "semantic graph not out-of-tree"
[ ! -e "$APP2/graphify-out" ]                                || fail "POLLUTION: semantic build wrote into the managed repo"
echo "  ok — semantic graph out-of-tree; managed repo clean"

echo "== refresh: ast rebuilds (no-LLM); semantic marks STALE (never auto-spends LLM) =="
"$SEARCH" refresh app >/dev/null 2>&1 || fail "ast refresh failed"
[ -f "$GJSON" ] || fail "ast graph gone after refresh"
"$SEARCH" refresh sem >/dev/null 2>&1 || fail "semantic refresh errored (should mark stale, not fail)"
"$SEARCH" status sem | grep -q 'STALE=' || fail "semantic graph not marked STALE after a land-refresh"
echo "  ok — ast refreshed in place; semantic flagged stale, not silently rebuilt"

echo "== fail-closed: off project, no graph, and absent tool all refuse (caller falls back to grep) =="
"$BIN/tl-project.sh" set none path "$APP"; "$BIN/tl-project.sh" set none graph_mode off
"$SEARCH" build none >/dev/null 2>&1 && fail "build should refuse when graph_mode=off"
[ "$("$SEARCH" status none)" = off ] || fail "status of an off project should be 'off'"
"$SEARCH" query none "x" >/dev/null 2>&1 && fail "query should refuse when there is no graph"
env PATH="/usr/bin:/bin" bash "$SEARCH" query app "x" >/dev/null 2>&1 \
  && fail "query should refuse (fall back to grep) when graphify is absent"
echo "  ok — off / no-graph / absent-tool all fail closed"

echo "== encapsulation (D1 done-when): only the adapter names graphify =="
leaked="$(grep -rlw graphify "$BIN" 2>/dev/null | grep -v '/tl-search.sh$' || true)"
[ -z "$leaked" ] || fail "graphify referenced outside the seam: $leaked"
echo "  ok — no bin/ file other than tl-search.sh references graphify"

echo "PASS: tl-search builds out-of-tree (both modes), answers queries, refreshes correctly, fails closed, and no other script names graphify"
