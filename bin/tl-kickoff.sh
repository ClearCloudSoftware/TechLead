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
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

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

tdir="$(mktemp -d)"; trap 'rm -rf "$tdir"' EXIT
max="${TL_KICKOFF_MAX:-10}"; turn=0
while :; do
  turn=$((turn+1))
  [ "$turn" -le "$max" ] || { tl_log "hit the question cap ($max) — re-run to continue if it didn't wrap up"; exit 0; }
  # Each turn is a model call of a few seconds; via a file, not `$( )`, so it can run under a spinner
  # (tl_spin cannot show a command substitution — see its contract in tl-common.sh).
  tl_spin "the lead is thinking…" sh -c "'$cmd' < '$transcript' > '$tdir/turn.out'" \
    || tl_die "kickoff driver failed"
  out="$(cat "$tdir/turn.out")"
  [ -n "$out" ] || tl_die "the kickoff driver returned nothing (harness/adapter misconfigured?) — check TL_KICKOFF_CMD"
  case "$out" in
    *"<CONTEXT>"*)   # the lead is done: extract the docs
      ctx="$(printf '%s\n' "$out" | awk '/<CONTEXT>/{f=1;next} /<\/CONTEXT>/{f=0} f')"
      backlog="$(printf '%s\n' "$out" | awk '/<BACKLOG>/{f=1;next} /<\/BACKLOG>/{f=0} f')"
      [ -n "$ctx" ] || tl_die "driver emitted no CONTEXT body — paused; re-run tl-kickoff $name to continue"
      printf '%s\n' "$ctx" > "$target"; rm -f "$transcript"
      echo "" >&2
      echo "tl: drafted $target (uncommitted). REVIEW it — the domain is yours to approve — then commit:" >&2
      echo "      git -C \"$path\" add CONTEXT.md && git -C \"$path\" commit -m 'add CONTEXT.md'" >&2
      # "REVIEW it" used to mean "go open it yourself". Show it, rendered, when someone is watching;
      # captured output is untouched so the smoke test still sees only its own lines.
      [ -n "${TL_DECORATE:-}" ] && tl_page "$target" >&2
      if [ -n "$backlog" ]; then
        # The lines are always printed — they are the record of what the lead proposed, and the
        # non-interactive contract (test/kickoff-smoke.sh K1) is that you can copy them.
        echo "tl: seed backlog — the lead proposes:" >&2
        printf '%s\n' "$backlog" | while IFS='|' read -r slug title desc; do
          [ -n "$slug" ] || continue
          # readable + paste-safe: double-quote, escaping only the chars special inside double quotes
          qt="$(printf '%s' "$title" | sed 's/[\\"$`]/\\&/g')"
          qd="$(printf '%s' "$desc"  | sed 's/[\\"$`]/\\&/g')"
          printf '      tl-backlog add %s "%s" "%s"\n' "$slug" "$qt" "$qd" >&2
        done
        # At a terminal, offer to add them instead of making you paste. Selecting an item IS the
        # approval — the same curate-then-commit shape as `tl-grill prune`. Nothing is added unless
        # you pick it, and whatever you skip is still printed above to run later.
        if [ -t 0 ]; then
          printf '%s\n' "$backlog" | awk -F'|' 'NF && $1!=""{printf "%s — %s\n", $1, $2}' > "$tdir/items"
          if [ -s "$tdir/items" ]; then
            items_arr=(); nitems=0
            while IFS= read -r l; do
              [ -n "$l" ] || continue
              items_arr+=("$l"); nitems=$((nitems+1))
            done < "$tdir/items"
            # nitems, not ${#items_arr[@]}: bash 3.2 (macOS's) errors on "${arr[@]}" when the array
            # is empty and set -u is on, so never let the expansion below happen with nothing in it.
            [ "$nitems" -gt 0 ] || exit 0
            tl_pick_many KICKOFF_BACKLOG "add which to the backlog?" "${items_arr[@]}" > "$tdir/keep" || true
            added=0
            while IFS= read -r picked; do
              [ -n "$picked" ] || continue
              s="${picked%% —*}"
              line="$(printf '%s\n' "$backlog" | awk -F'|' -v s="$s" '$1==s{print;exit}')"
              [ -n "$line" ] || continue
              t="$(printf '%s' "$line" | awk -F'|' '{print $2}')"
              d="$(printf '%s' "$line" | awk -F'|' '{print $3}')"
              "$BIN/tl-backlog.sh" add "$s" "$t" "$d" >/dev/null && added=$((added+1))
            done < "$tdir/keep"
            [ "$added" -gt 0 ] && tl_log "added $added item(s) to the backlog — tl-backlog list"
          fi
        fi
      fi
      exit 0 ;;
    *)               # a question: show it, record it, capture the owner's answer
      # Framed so the lead's question is visibly not your own typing — this is a conversation, and
      # the two used to run together as undifferentiated text.
      if [ -n "${TL_DECORATE:-}" ] && command -v gum >/dev/null 2>&1; then
        echo >&2
        gum style --border rounded --border-foreground 212 --padding "0 1" --width 78 \
          "LEAD  $out" >&2
      else
        printf '\nLEAD: %s\n' "$out" >&2
      fi
      printf 'LEAD: %s\n' "$out" >> "$transcript"
      # NOT tl_text: it short-circuits to its default when stdin is not a tty, which would silently
      # skip the piped answers the smoke test feeds. The pause contract is stdin's (EOF or a blank
      # line), so the read has to be real. gum only stands in when there is a terminal to type at.
      if [ -t 0 ] && command -v gum >/dev/null 2>&1; then
        ans="$(gum input --placeholder "your answer (empty to pause)" --char-limit=0 --width 78)" \
          || { echo >&2; tl_log "paused — resume with: tl-kickoff $name"; exit 0; }
      else
        printf '> ' >&2
        IFS= read -r ans || { echo >&2; tl_log "paused — resume with: tl-kickoff $name"; exit 0; }
      fi
      printf 'OWNER: %s\n' "$ans" >> "$transcript"
      ;;
  esac
done
