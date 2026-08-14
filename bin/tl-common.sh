#!/usr/bin/env bash
# tl-common.sh — shared helpers, sourced by every bin/tl-*.sh.
#
# Capability guard (§3.9): refuse to operate unless TL_HOME marks a real instance.
# This is capability removal, not a prompt instruction — an agent in some other checkout
# cannot reach the fleet just by wanting to; the entry point exits first.

if [ -z "${TL_HOME:-}" ]; then
  echo "tl: refusing — TL_HOME is not set (capability guard, §3.9)" >&2
  exit 78
fi
if [ ! -f "$TL_HOME/AGENTS.md" ]; then
  echo "tl: refusing — TL_HOME ($TL_HOME) is not a TechLead instance (no AGENTS.md)" >&2
  exit 78
fi

# Instance config (§3.2, E11/W1): load once so the operator sets harness/model/adapters in one
# place instead of every shell. The file (written by tl-init, single owner) uses conditional
# assignments — `export X="${X:-val}"` — so anything already set in the shell wins over the file.
# Absent file is a silent no-op. tl-init writes to this same path.
TL_CONFIG="${TL_CONFIG:-$TL_HOME/config/instance.env}"; export TL_CONFIG
[ -f "$TL_CONFIG" ] && . "$TL_CONFIG"

# Per-project state (owner decision 2026-08-14): data/state/lead live in <project>/.techlead, NOT
# in TL_HOME. TL_HOME is the tool install (bin/, adapters/, AGENTS.md, config); every managed repo
# keeps its own working state beside its code — the same convention as .claude/ and .superpowers/.
# Resolution is "nearest ancestor wins": walk up from $PWD to the closest .techlead/ (so being *in*
# a project is what selects it — no multi-project ambiguity). Outside any project (e.g. tl-init) we
# fall back to TL_HOME so tool-level commands still work. An already-exported TL_DATA/TL_STATE/TL_LEAD
# wins over resolution — tl-new/tl-onboard use that to target the project they are creating.
tl__find_root() {   # echoes the nearest ancestor .techlead dir, or non-zero if none
  d="$PWD"
  while [ "$d" != / ]; do
    [ -d "$d/.techlead" ] && { printf '%s\n' "$d/.techlead"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}
TL_ROOT="$(tl__find_root || echo "$TL_HOME")"
TL_DATA="${TL_DATA:-$TL_ROOT/data}"
TL_STATE="${TL_STATE:-$TL_ROOT/state}"
TL_LEAD="${TL_LEAD:-$TL_ROOT/lead}"        # judgment layer, per-project (single owner of the path)
TL_WORKTREES="${TL_WORKTREES:-$TL_STATE/wt}"
mkdir -p "$TL_DATA" "$TL_STATE" "$TL_WORKTREES"
export TL_HOME TL_DATA TL_STATE TL_LEAD TL_WORKTREES   # so a spawned worker inherits its instance

tl_log() { _tl_say info "$*" >&2; }
tl_die() { _tl_say error "$1" >&2; exit "${2:-1}"; }
# Level-tagged when someone is watching, plain `tl: …` otherwise. The gate matters: worker output is
# captured and read back through tl-peek, and the smoke tests grep these lines.
_tl_say() {
  local lvl="$1"; shift
  if [ -n "${TL_DECORATE:-}" ] && command -v gum >/dev/null 2>&1; then
    gum log --level "$lvl" --prefix tl "$*"
  else
    printf 'tl: %s\n' "$*"
  fi
}

# Presentation (single owner: this file). Every tl-* line used to land with identical weight — a
# refusal read like a progress note. Colour separates "you must act" from "for your information".
# Gated on stdout being a tty, so captured output (`x="$(tl-spec.sh path ...)"`, pipes, the smoke
# tests' logs) is byte-identical to before — no escape codes ever reach a file or a grep.
# NO_COLOR (https://no-color.org) and TERM=dumb turn it off.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && command -v tput >/dev/null 2>&1; then
  TL_C_STOP="$(tput setaf 1 2>/dev/null || true)$(tput bold 2>/dev/null || true)"
  TL_C_OK="$(tput setaf 2 2>/dev/null || true)"
  TL_C_KEY="$(tput setaf 6 2>/dev/null || true)"
  TL_C_DIM="$(tput dim 2>/dev/null || true)"
  TL_C_0="$(tput sgr0 2>/dev/null || true)"
  TL_DECORATE=1
else
  TL_C_STOP=""; TL_C_OK=""; TL_C_KEY=""; TL_C_DIM=""; TL_C_0=""
  TL_DECORATE=""
fi

TL_PROG="$(basename "$0" .sh)"; case "$TL_PROG" in tl-*) ;; *) TL_PROG=tl;; esac
tl_stop() {   # owner must act — the loudest thing the toolbelt prints, so give it a frame
  if [ -n "${TL_DECORATE:-}" ] && command -v gum >/dev/null 2>&1; then
    gum style --border normal --border-foreground 1 --foreground 1 --padding "0 1" \
      "$TL_PROG: STOP — $*"
  else
    printf '%s%s: STOP%s — %s\n' "$TL_C_STOP" "$TL_PROG" "$TL_C_0" "$*"
  fi
}
tl_ok()   { printf '%s%s: %s%s\n' "$TL_C_OK" "$TL_PROG" "$*" "$TL_C_0"; }            # it worked
tl_kv()   { printf '  %s%-7s%s %s\n' "$TL_C_KEY" "$1:" "$TL_C_0" "$2"; }   # cause:/fix:/next: lines
tl_note() { printf '  %s%s%s\n' "$TL_C_DIM" "$*" "$TL_C_0"; }              # paths, provenance

# tl_table "Col1,Col2,…"  <- TAB-separated rows on stdin. The single owner of tabular DISPLAY;
# the machine-readable forms (tl-spec qlist's pipe encoding, findings.json) are untouched, so
# nothing that parses this data goes through here.
#   watched at a terminal, gum installed -> `gum table --print` (bordered)
#   otherwise -> an awk that measures each column. NOT `column -t`: BSD column silently drops
#                empty fields, so one null path shifts every later cell into the wrong column.
# The box is gated on TL_DECORATE (stdout is a tty) for the same reason as colour, and it matters
# more here: `tl-cost report | awk '$1=="answer"{print $2}'` is a real caller, and box-drawing
# characters would shift every field. Captured output stays whitespace-columned and parseable.
# Buffered to a temp file first so a gum failure falls back to awk instead of eating the rows.
# TL_NO_TABLE=1 forces the plain form — gum table truncates rather than wraps, so a long question
# in a narrow terminal is better read unboxed.
tl_table() {
  local cols="$1" t; t="$(mktemp)"; cat > "$t"
  [ -s "$t" ] || { rm -f "$t"; return 0; }
  if [ -n "${TL_DECORATE:-}" ] && [ -z "${TL_NO_TABLE:-}" ] && command -v gum >/dev/null 2>&1 &&
     gum table --print --lazy-quotes --separator="$(printf '\t')" --columns="$cols" < "$t" 2>/dev/null
  then rm -f "$t"; return 0; fi
  awk -F'\t' -v hdr="$cols" -v k="$TL_C_KEY" -v z="$TL_C_0" '
    BEGIN{ n=split(hdr,H,",") }
    { for(i=1;i<=NF;i++){ C[NR,i]=$i; if(length($i)>w[i]) w[i]=length($i) }
      if(NF>n) n=NF; R=NR }
    END{
      for(i=1;i<=n;i++) if(length(H[i])>w[i]) w[i]=length(H[i])
      s=""; for(i=1;i<=n;i++) s=s sprintf("%-*s  ", w[i], H[i]); sub(/ +$/,"",s)
      print "  " k s z
      for(r=1;r<=R;r++){ s=""
        for(i=1;i<=n;i++) s=s sprintf("%-*s  ", w[i], C[r,i]); sub(/ +$/,"",s); print "  " s }
    }' "$t"
  rm -f "$t"
}

# tl_spin "title" cmd args…  — a spinner while a slow thing runs (test suite, LLM adapter).
# The caller MUST keep its own redirections INSIDE the command, e.g.
#   tl_spin "running tests…" sh -c "cd '$wt' && { $cmd; } >'$out' 2>/dev/null"
# gum spin swallows the command's output unless --show-output, and --show-output also merges stderr
# into stdout — which would inject adapter chatter straight into a stream we parse. Keeping the
# redirection inside the command means gum has nothing to show and nothing to merge.
# Exit status propagates (tl-gate's `|| trc=$?` depends on it).
tl_spin() {
  local title="$1"; shift
  if [ -n "${TL_DECORATE:-}" ] && command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    "$@"
  fi
}

# tl_page <file> — show the owner something they are about to decide about.
# Plain `cat` when not decorating, so captured output is byte-identical. Markdown gets rendered.
# Paged ONLY when it would not fit: a pager over a six-line report is worse than no pager, and the
# thing it fixes is real — tl-approve used to cat a long report and then print the prompt below it,
# pushing the report you are judging off the top of the screen.
tl_page() { # <file>
  local f="$1" rows total
  [ -f "$f" ] || return 0
  if [ -z "${TL_DECORATE:-}" ]; then cat "$f"; return 0; fi
  rows="$(tput lines 2>/dev/null || echo 24)"
  total="$(wc -l < "$f" | tr -d ' ')"
  if [ "$total" -le "$((rows - 6))" ]; then _tl_render "$f"; return 0; fi
  LESS="${LESS:-R}" ; export LESS          # else a bare $PAGER=less shows the render's escape codes
  if [ -n "${PAGER:-}" ]; then _tl_render "$f" | $PAGER
  elif command -v gum >/dev/null 2>&1; then _tl_render "$f" | gum pager
  else _tl_render "$f" | less -R 2>/dev/null || _tl_render "$f"
  fi
}
_tl_render() {  # markdown through a renderer when we have one; anything else raw
  case "$1" in
    *.md)
      command -v glow >/dev/null 2>&1 && { glow -s auto "$1" && return 0; }
      command -v gum  >/dev/null 2>&1 && { gum format < "$1" && return 0; } ;;
  esac
  cat "$1"
}

# bump_hits <lead-file> <ordinal>...  — increment `hits:` and stamp `last:` on the Nth `### ` entry
# (1-indexed in file order — the same numbering the grill/review adapter shows the model). The reuse
# counter is the risk-1 / D13 signal (§2.6, SHAPE.md): a question fires on a grill, a rubric rule fires
# on a review. Out-of-range ordinals simply don't match, so a garbled ref is a silent no-op. Single
# owner of the hits: write, shared by tl-grill (questions.md) and tl-standards (review-rubric.md).
bump_hits() {
  local file="$1"; shift
  [ -f "$file" ] || return 0
  local ords date tmp
  ords=" $* "; date="$(date -u +%Y-%m-%d)"; tmp="$(mktemp)"
  awk -v ords="$ords" -v date="$date" '
    /^### /{ sec++ }
    /^hits:/ && index(ords, " " sec " ") > 0 {
      sub(/hits:[[:space:]]*[0-9]+/, "hits: " ($2 + 1))
      sub(/last:[[:space:]]*[^[:space:]].*/, "last: " date)
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Harness visibility (§2.7, §3.11): a worker's worktree branches from HEAD and the gate runs there too,
# so anything UNCOMMITTED in the project — most painfully the test harness — is invisible to both. The
# baseline (run against the working tree) then measures something the worker/gate never see. Warn at the
# chokepoints so that fails loud instead of silently. Returns 0 if clean, 1 if it warned.
tl_warn_uncommitted() { # <repo-path> <trailing advice>
  local repo="$1" advice="${2:-}" dirty
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null)" || return 0   # not a git repo → nothing to check
  [ -n "$dirty" ] || return 0
  tl_log "⚠ uncommitted changes in $repo — a worker branches from HEAD (and the gate runs there), so"
  tl_log "  these are INVISIBLE to it, including your test harness. $advice"
  printf '%s\n' "$dirty" | sed 's/^/    /' >&2
  return 1
}

# Seed the lead/ file skeleton — the E6.2/§2.4 SHAPE only, never borrowed judgment (lead/README is
# explicit that principles must accrete from real grills). Per-project now (owner decision
# 2026-08-14): each managed repo grows its own judgment. Existing files are left untouched.
tl_seed_lead() { # <lead-dir>
  local L="$1"; mkdir -p "$L/decisions"
  [ -e "$L/decisions/.gitkeep" ] || : > "$L/decisions/.gitkeep"
  local f
  for f in principles review-rubric delegation escalation questions voice; do
    [ -f "$L/$f.md" ] && continue
    printf '# %s\n\n<!-- stub (tl-scaffold). Shape: lead/SHAPE.md. Fill from real grills; do not seed borrowed judgment (lead/README). -->\n' "$f" > "$L/$f.md"
  done
}

# Create <root>/.techlead/{data,state,lead} for a managed repo and keep it out of the repo's history
# (like .claude/.superpowers — private working state, not source). Single owner of the .techlead shape.
tl_scaffold_project() { # <project-root>
  local root="$1" th="$1/.techlead"
  mkdir -p "$th/data/projects" "$th/state" "$th/lead"
  tl_seed_lead "$th/lead"
  if [ -d "$root/.git" ] && ! grep -qxF '.techlead/' "$root/.gitignore" 2>/dev/null; then
    printf '.techlead/\n' >> "$root/.gitignore"
  fi
}

# task metadata — one key=value per line in state/<id>.meta (§3.2). Single owner of task state.
tl_meta_file() { printf '%s/%s.meta' "$TL_STATE" "$1"; }
tl_meta_get() { # id key -> value on stdout; non-zero if the file is missing
  [ -f "$(tl_meta_file "$1")" ] || return 1
  awk -v k="$2" 'index($0,k"=")==1{sub(/^[^=]*=/,"");print;exit}' "$(tl_meta_file "$1")"
}
tl_meta_set() { # id key value  (rewrite so last value wins on read — not an event log)
  local f tmp; f="$(tl_meta_file "$1")"; tmp="$(mktemp)"
  { [ -f "$f" ] && grep -v "^$2=" "$f" || true; printf '%s=%s\n' "$2" "$3"; } > "$tmp"
  mv "$tmp" "$f"
}

tl_now() { date +%s; }
tl_mtime() { stat -f %m "$1" 2>/dev/null || echo 0; }   # tl: macOS BSD stat — `stat -c %Y` on GNU

# APPEND-ONLY event log (§3.4). Workers append only wake-worthy transitions; nothing on silent
# resume. tl_status_last returns the last *event's* verb — a hint for tl-state to reconcile, NOT
# the current state. Read current state through bin/tl-state.sh, never this tail.
tl_status_file() { printf '%s/%s.status' "$TL_STATE" "$1"; }
tl_status_last() { tail -n 1 "$(tl_status_file "$1")" 2>/dev/null | awk -F'\t' '{print $2}'; }
