#!/usr/bin/env bash
# tl-kickoff.sh — greenfield project ideation as a TERMINAL interview (E9.2, #60). A brand-new repo has
# no domain to derive, so it comes from the owner — but entirely from the shell, no Claude Code app.
#
# Each turn is a discrete `claude -p` call (no LLM in the supervision loop, §3.5), and the running
# conversation lives in a transcript FILE — killable/reconstructable (§3.2): kill it mid-interview and
# re-run to resume. A plain transcript (not claude session files) keeps it harness-agnostic (§5) and
# owned by TechLead (§3.1). When the lead has enough it emits the CONTEXT.md (domain glossary) + a seed
# backlog; both land draft-then-approve — CONTEXT.md written uncommitted (owner reviews+commits), the
# backlog printed as ready `tl-backlog add` lines (owner curates). Existing repo → tl-scaffold-context.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"

# <project> optional: default to the sole project registered in the current .techlead.
name="${1:-}"
if [ -z "$name" ]; then
  name="$(tl_current_project)" || tl_die "run from inside a project (or pass its name). Registered here: $(ls "$TL_DATA/projects" 2>/dev/null | sed 's/\.conf$//' | tr '\n' ' ')"
fi
path="$("$BIN/tl-project.sh" get "$name" path)" || tl_die "unknown project: $name (tl-new/tl-onboard it first)"
target="$path/CONTEXT.md"
if [ -e "$target" ]; then tl_die "$target already exists — edit it by hand (refusing to overwrite)"; fi

cmd="${TL_KICKOFF_CMD:-$TL_HOME/adapters/claude-kickoff.sh}"
[ -x "$cmd" ] || tl_die "no kickoff driver — set TL_KICKOFF_CMD (e.g. adapters/claude-kickoff.sh), or write $target by hand"

transcript="$TL_DATA/kickoff-$name.transcript"; mkdir -p "$TL_DATA"
if [ -f "$transcript" ]; then tl_log "resuming the kickoff interview for '$name'"
else printf 'PROJECT: %s\n(no answers yet — ask your first question)\n' "$name" > "$transcript"; fi

echo "tl: kickoff interview for '$name' — the lead asks one question at a time; answer each." >&2
echo "tl: (blank line + Enter, or Ctrl-D, pauses — re-run tl-kickoff to resume from where you left off.)" >&2

max="${TL_KICKOFF_MAX:-10}"; turn=0
while :; do
  turn=$((turn+1))
  [ "$turn" -le "$max" ] || { tl_log "hit the question cap ($max) — re-run to continue if it didn't wrap up"; exit 0; }
  out="$("$cmd" < "$transcript")" || tl_die "kickoff driver failed"
  case "$out" in
    *"<CONTEXT>"*)   # the lead is done: extract the docs
      ctx="$(printf '%s\n' "$out" | awk '/<CONTEXT>/{f=1;next} /<\/CONTEXT>/{f=0} f')"
      backlog="$(printf '%s\n' "$out" | awk '/<BACKLOG>/{f=1;next} /<\/BACKLOG>/{f=0} f')"
      [ -n "$ctx" ] || tl_die "driver emitted no CONTEXT body — paused; re-run tl-kickoff $name to continue"
      printf '%s\n' "$ctx" > "$target"; rm -f "$transcript"
      echo "" >&2
      echo "tl: drafted $target (uncommitted). REVIEW it — the domain is yours to approve — then commit:" >&2
      echo "      git -C \"$path\" add CONTEXT.md && git -C \"$path\" commit -m 'add CONTEXT.md'" >&2
      if [ -n "$backlog" ]; then
        echo "tl: seed backlog — run the ones you want:" >&2
        printf '%s\n' "$backlog" | while IFS='|' read -r slug title desc; do
          [ -n "$slug" ] || continue
          printf '      tl-backlog add %s %s %s\n' "$slug" "$(printf %q "$title")" "$(printf %q "$desc")" >&2
        done
      fi
      exit 0 ;;
    *)               # a question (it streamed to the terminal as it generated); record + capture answer
      printf 'LEAD: %s\n' "$out" >> "$transcript"
      printf '\n> ' >&2
      IFS= read -r ans || { echo >&2; tl_log "paused — resume with: tl-kickoff $name"; exit 0; }
      printf 'OWNER: %s\n' "$ans" >> "$transcript"
      ;;
  esac
done
