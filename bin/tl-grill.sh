#!/usr/bin/env bash
# tl-grill.sh — MECHANICS ONLY (§2.4, §3.10). Resolves a backlog item, allocates the task id,
# scaffolds spec.md, runs the inference pass by handing lead/questions.md + prior decisions/ to a
# grill driver, and validates structured fields. It never reads prose to decide whether a question
# is answered — question selection and phrasing are semantic policy in lead/questions.md.
#
# Subcommands: <slug> (grill) · answer ID [QID STATE [text]] · reject ID reason · show ID ·
#              propose SLUG · prune SLUG · promote SLUG
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"
BACKLOG="${TL_BACKLOG:-$TL_DATA/backlog.md}"
TAB="$(printf '\t')"

slugify() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'; }

_finalize() {  # id — set state from open-count, then report  (bump_hits lives in tl-common.sh)
  local id="$1" open total
  open="$("$BIN/tl-spec.sh" open-count "$id")"
  total="$("$BIN/tl-spec.sh" qlist "$id" | awk 'END{print NR}')"
  if [ "$open" -eq 0 ]; then "$BIN/tl-spec.sh" set "$id" state specified
  else "$BIN/tl-spec.sh" set "$id" state drafted; fi
  echo "tl: $id — state=$("$BIN/tl-spec.sh" get "$id" state), $open open question(s)"
  # An empty bank yields 0 questions; tl-run then refuses to dispatch (fail closed, #49). Say so here
  # so a bare `tl-grill` run doesn't look like a clean pass when nothing was actually asked.
  [ "$total" -eq 0 ] && echo "tl: ⚠ no questions produced — $TL_LEAD/questions.md is empty (#49); the grill had nothing to ask." || true
  "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' -v OFS='\t' '{print $1,$2,$3,$5}' \
    | tl_table "QID,STATE,SOURCE,QUESTION"
  if [ "$open" -gt 0 ]; then
    echo "tl: answer the delta:"
    tl_kv walk "tl-grill answer $id        (one question at a time, in this terminal)"
    tl_kv or   "tl-grill answer $id <qid> <decided|leaning|spike> [text]"
  fi
}

# _answer id qid state [text] — THE one writer for an owner answer. Both the argument form and the
# interactive walk go through here, so the correction log and the D13 metric can't drift apart (§3.1).
# Empty text keeps whatever the question already says.
_answer() {
  local id="$1" qid="$2" st="$3" text="${4:-}" t0 cur psrc pstate
  t0="$(date +%s)"
  [ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id"
  cur="$("$BIN/tl-spec.sh" qlist "$id" | awk -F'|' -v q="$qid" '$1==q{print;exit}')"
  [ -n "$cur" ] || tl_die "no such question $qid in $id"
  case "$st" in decided|leaning|open|spike) ;; *) tl_die "answer_state must be decided|leaning|open|spike";; esac
  [ -n "$text" ] || text="$(printf '%s' "$cur" | awk -F'|' '{print $5}')"
  # E6.4 risk-1 data (§2.6, §8.1): overriding an inferred *value* (not an open delta) is a labeled
  # correction — log it. accepts are latent (source stays `inferred`); tl-metric outcome folds both.
  psrc="$(printf '%s' "$cur" | awk -F'|' '{print $3}')"; pstate="$(printf '%s' "$cur" | awk -F'|' '{print $2}')"
  case "$psrc:$pstate" in
    inferred:decided|inferred:leaning|inferred:spike)
      printf '%s\t%s\t%s\tcorrect\t%s\n' "$(date -u +%Y-%m-%d)" "$id" "$qid" "$pstate->$st" \
        >> "$TL_DATA/inferred-outcomes.tsv" ;;
  esac
  "$BIN/tl-spec.sh" qset "$id" "$qid" "$st" owner "$(date -u +%Y-%m-%d)" "$text"
  "$BIN/tl-metric.sh" record "$id" grill "$(( $(date +%s) - t0 ))" || true   # D13 input (E1.5)
}

# _answer_loop id — walk the OPEN questions one at a time in the terminal, instead of making the owner
# retype `tl-grill answer <id> <qid> <state> "..."` per question. Mechanics only: it presents the
# questions the grill produced and records what the owner says. It never decides an answer itself.
_answer_loop() {
  local id="$1" openf n=0 qid cur_st cur_src cur_at cur_text st text
  # No tty = no owner. Fail closed (§3.9) rather than bulk-accepting the inferred answers: a silent
  # "decided" on every open question is exactly the rubber stamp the grill exists to prevent.
  [ -t 0 ] || tl_die "no tty for the interactive walk — use: tl-grill answer $id <qid> <decided|leaning|spike> [text]"
  openf="$(mktemp)"
  "$BIN/tl-spec.sh" qlist "$id" | awk -F'|' '$2=="open"' > "$openf"
  [ -s "$openf" ] || { rm -f "$openf"; tl_log "no open questions in $id — nothing to answer."; return 0; }
  # Read the snapshot on fd 4: _answer rewrites spec.md as we go, and stdin has to stay the terminal
  # so the prompts below can read it.
  while IFS='|' read -r qid cur_st cur_src cur_at cur_text <&4; do
    [ -n "$qid" ] || continue
    n=$((n+1))
    # The question travels IN the prompt, not as a line echoed before it: a picker repaints the
    # screen, so anything printed first is gone by the time you are looking at the choices.
    # TL_YES is the WIZARDS' "take every default" switch. Letting it reach here would stamp every
    # open question `decided` with the inferred text — the exact rubber stamp the guard above refuses.
    # Blank it for the prompts; TL_ANSWER_<KEY> is the deliberate per-question override.
    st="$(TL_YES= tl_choose "GRILL_${qid}_STATE" "[$qid] $cur_text" decided decided leaning spike open)"
    # Empty default on purpose: for an OPEN question the stored text is the QUESTION, not a draft
    # answer, so pre-filling it would make you erase the question before every answer. Submitting
    # empty falls through to _answer, which keeps whatever the question already says.
    text="$(TL_YES= tl_text "GRILL_${qid}_TEXT" "[$qid] $cur_text — your answer" "")"
    _answer "$id" "$qid" "$st" "$text"
  done 4< "$openf"
  rm -f "$openf"
  tl_log "recorded $n answer(s) for $id"
}

case "${1:-}" in
  answer)  # answer ID [QID STATE [text...]]  — without QID, walk the open questions interactively
    id="${2:?usage: tl-grill answer ID [QID STATE [text]]}"
    if [ "$#" -lt 4 ]; then _answer_loop "$id"; _finalize "$id"; exit 0; fi
    qid="$3"; st="$4"; shift 4 || true
    _answer "$id" "$qid" "$st" "${*:-}"
    _finalize "$id"; exit 0 ;;
  reject)  # reject ID reason...  — terminal "don't build this" (D10, §7.3)
    id="${2:?}"; shift 2 || true; reason="${*:-unspecified}"
    [ -f "$("$BIN/tl-spec.sh" path "$id")" ] || tl_die "no spec for $id"
    "$BIN/tl-spec.sh" set "$id" state rejected
    printf '\n## Rejected\n\n%s\n' "$reason" >> "$("$BIN/tl-spec.sh" path "$id")"
    printf '%s\trejected\t%s\t%s\n' "$(date -u +%Y-%m-%d)" "$("$BIN/tl-spec.sh" get "$id" backlog)" "$reason" \
      >> "$TL_DATA/backlog.decisions"
    tl_log "grill: rejected $id — $reason"; exit 0 ;;
  propose) # propose SLUG — draft candidate questions for a backlog item into data/proposals/ (#49).
    # Bootstrap for a thin/empty bank: the LLM proposes questions the owner curates + promotes. Never
    # writes lead/ — goes through tl-propose's propose-not-write file machinery, with a grill-specific
    # proposer. Owner disposes (prune the file, then `tl-grill promote SLUG`).
    slug="${2:?usage: tl-grill propose <backlog-slug>}"
    [ -f "$BACKLOG" ] || tl_die "no backlog at $BACKLOG"
    title="$(awk -v s="$slug" 'index($0,"## "s":")==1{t=$0; sub("^## [^:]*: *","",t); print t; exit}' "$BACKLOG")"
    [ -n "$title" ] || tl_die "backlog item '$slug' not found (want a heading '## $slug: <title>')"
    bodyf="$(mktemp)"
    awk -v s="$slug" 'index($0,"## "s":")==1{f=1;next} f&&index($0,"## ")==1{f=0} f{print}' "$BACKLOG" > "$bodyf"
    TL_PROPOSE_CMD="${TL_GRILL_PROPOSE_CMD:-$TL_HOME/adapters/claude-grill-propose.sh}" \
    TL_PROP_SOURCE="backlog item '$slug'" \
      "$BIN/tl-propose.sh" question "$slug" "$bodyf"
    rm -f "$bodyf"
    echo "tl: candidates for '$slug' — drop the ones you don't want, then promote:"
    tl_kv prune "tl-grill prune $slug     (pick them in the terminal)"
    tl_kv then  "tl-grill promote $slug"
    exit 0 ;;
  prune)   # prune SLUG — pick which drafted candidates survive, in the terminal.
    # `promote` has always taken "whatever '### ' headings the owner left in the file", which made
    # curation an editor chore. This is the same operation as a multi-select, so offer it as one and
    # rewrite the proposal in place. Still owner-only, still nothing written into lead/ (that's promote).
    slug="${2:?usage: tl-grill prune <backlog-slug>}"
    prop="$TL_DATA/proposals/question-$slug.md"
    [ -f "$prop" ] || tl_die "no proposal for '$slug' at ${prop#"$TL_DATA"/} — run: tl-grill propose $slug"
    # A slug has dashes; env-var keys can't. Sanitise once and use the same key for both the
    # scripted-override check and the picker, so TL_ANSWER_GRILL_PRUNE_<SLUG> drives it end to end.
    pkey="GRILL_PRUNE_$(printf '%s' "$slug" | tr -c 'A-Za-z0-9' '_' | tr 'a-z' 'A-Z')"
    eval "pov=\${TL_ANSWER_${pkey}:-}"
    [ -n "$pov" ] || [ -t 0 ] || tl_die "no tty — edit $prop by hand, then: tl-grill promote $slug"
    cands="$(mktemp)"; awk '/^### /{sub(/^### /,"");print}' "$prop" > "$cands"
    [ -s "$cands" ] || { rm -f "$cands"; tl_die "no '### ' candidates in ${prop#"$TL_DATA"/} (already pruned?)"; }
    keep="$(mktemp)"
    cand_arr=()                                  # one arg per candidate — questions contain spaces
    while IFS= read -r line; do [ -n "$line" ] && cand_arr+=("$line"); done < "$cands"
    tl_pick_many "$pkey" "keep which questions?" "${cand_arr[@]}" > "$keep"
    kept="$(awk 'END{print NR+0}' "$keep")"
    if [ "$kept" -eq 0 ]; then
      rm -f "$cands" "$keep"; tl_log "kept nothing — left $prop untouched. Re-run, or delete it."; exit 0
    fi
    # Drop each unkept '### ' section (heading + body) but leave the header and '## ' sections alone.
    tmp="$(mktemp)"
    awk 'BEGIN{keep=1}                       # the file header + triggering case are not candidates
         NR==FNR{K[$0]=1;next}
         /^### /{ keep=(substr($0,5) in K) }
         /^## /{ keep=1 }                    # "## " never matches "### " — section headings survive
         keep' "$keep" "$prop" > "$tmp" && mv "$tmp" "$prop"
    rm -f "$cands" "$keep"
    tl_log "kept $kept candidate(s) in ${prop#"$TL_DATA"/}"
    echo "tl: now promote them into lead/questions.md:  tl-grill promote $slug"
    exit 0 ;;
  promote) # promote SLUG — append the surviving candidates to lead/questions.md, then archive.
    # Owner-driven (the one write into lead/, and only after the owner pruned the proposal). Proposed
    # questions enter provisional: hits: 0 and an unproven scar; the junk-drawer defense (D4) prunes
    # any that never fire (Q8=a).
    slug="${2:?usage: tl-grill promote <backlog-slug>}"
    prop="$TL_DATA/proposals/question-$slug.md"
    [ -f "$prop" ] || tl_die "no proposal for '$slug' at ${prop#"$TL_DATA"/} — run: tl-grill propose $slug"
    qfile="$TL_LEAD/questions.md"; mkdir -p "$TL_LEAD"
    n=0
    # survivors = the h3 question headings the owner left in the file
    while IFS= read -r q; do
      [ -n "$q" ] || continue
      { printf '\n### %s\nhits: 0   last: —\n_scar:_ (proposed — unproven)\n' "$q"; } >> "$qfile"
      n=$((n+1))
    done <<EOF2
$(awk '/^### /{sub(/^### /,"");print}' "$prop")
EOF2
    if [ "$n" -eq 0 ]; then
      echo "tl: nothing to promote for '$slug' — no '### ' candidates left in ${prop#"$TL_DATA"/} (all pruned?)."
      exit 0
    fi
    mv "$prop" "$prop.promoted"
    tl_log "promoted $n question(s) into ${qfile#"$TL_LEAD"/} (provisional, hits:0) — archived ${prop#"$TL_DATA"/}.promoted"
    echo "tl: now re-grill against the seeded bank:  tl-run $slug   (or tl-grill $slug)"
    exit 0 ;;
  show) tl_page "$("$BIN/tl-spec.sh" path "${2:?}")"; exit 0 ;;
esac

# ---- default: start/refresh a grill for a backlog slug ----
slug="${1:?usage: tl-grill <backlog-slug> | answer|reject|show ...}"
t0="$(date +%s)"
[ -f "$BACKLOG" ] || tl_die "no backlog at $BACKLOG"
title="$(awk -v s="$slug" 'index($0,"## "s":")==1{t=$0; sub("^## [^:]*: *","",t); print t; exit}' "$BACKLOG")"
[ -n "$title" ] || tl_die "backlog item '$slug' not found (want a heading '## $slug: <title>')"
bodyf="$(mktemp)"
awk -v s="$slug" 'index($0,"## "s":")==1{f=1;next} f&&index($0,"## ")==1{f=0} f{print}' "$BACKLOG" > "$bodyf"

id="tl-$(slugify "$slug")"
[ -f "$("$BIN/tl-spec.sh" path "$id")" ] || "$BIN/tl-spec.sh" init "$id" "$slug" "$title" "$bodyf"
tl_log "grill: $id — inference pass over lead/questions.md"

: "${TL_GRILL_CMD:?tl: no grill driver — set TL_GRILL_CMD (e.g. adapters/claude-grill.sh)}"
# driver emits one line per question:  qid <TAB> answer_state <TAB> source <TAB> text [<TAB> bank#]
# The optional 5th field is the number of the lead/questions.md entry this answer was inferred from
# (§2.6 hits: signal). Old 4-field drivers just omit it → no bump.
# project context (§2.7, #60): if the grill runs inside a managed repo, feed the driver the repo's own
# AGENTS.md + CONTEXT.md (layout, conventions, danger zones, domain glossary) so inferences use the
# project's vocabulary, not just lead/. Resolved from the .techlead parent; absent files are skipped.
ctx="$(mktemp)"; techroot="$(dirname "$TL_DATA")"
if [ "$(basename "$techroot")" = ".techlead" ]; then
  for f in "$(dirname "$techroot")/AGENTS.md" "$(dirname "$techroot")/CONTEXT.md"; do
    if [ -f "$f" ]; then { printf '\n# from %s\n' "$(basename "$f")"; cat "$f"; } >> "$ctx"; fi
  done
fi
# The driver's output lands in a file rather than a pipe: it is a model call that takes tens of
# seconds, so it runs under a spinner (tl_spin, which cannot show a pipe), and reading from a file
# also takes the loop out of the pipe subshell — bank refs no longer need a temp file to escape it.
drv="$(mktemp)"; brefs="$(mktemp)"
# tl: two-tier bank read (SHAPE.md, owner 2026-08-14) — the grill should see the owner-global bank
#   ($TL_HOME/lead/questions.md) concatenated BEFORE the per-project one, so `global ++ project`.
# ponytail: single-tier read for now — no managed projects to merge with (data/projects/ empty), and
#   when $TL_LEAD == $TL_HOME/lead the two are the same file. Upgrade path: when $TL_LEAD differs and
#   its questions.md exists, write `cat $TL_HOME/lead/questions.md <project>/questions.md` to a temp
#   and point TL_QUESTIONS at it (global first — the driver numbers entries in file order, and the
#   bump_hits offset-split below relies on global occupying ordinals 1..G).
export TL_GRILL_ID="$id" TL_GRILL_SLUG="$slug" TL_GRILL_TITLE="$title" TL_GRILL_BODY="$bodyf" \
       TL_QUESTIONS="$TL_LEAD/questions.md" TL_DECISIONS="$TL_LEAD/decisions" TL_CONTEXT="$ctx"
# Lenient on a non-zero driver, as the pipeline was: whatever it emitted is still parsed, and an
# empty result fails closed downstream (tl-run refuses to dispatch un-grilled work, #49).
tl_spin "grill: inference pass over lead/questions.md…" sh -c "$TL_GRILL_CMD > '$drv'" \
  || tl_log "grill driver exited non-zero — parsing whatever it emitted"
while IFS="$TAB" read -r qid st src text bank; do
  [ -n "$qid" ] || continue
  case "$st"  in decided|leaning|open|spike) ;; *) st=open;;  esac   # validate; unknown -> open (fail closed)
  case "$src" in owner|inferred) ;; *) src=inferred;; esac
  "$BIN/tl-spec.sh" qset "$id" "$qid" "$st" "$src" "$(date -u +%Y-%m-%d)" "$text"
  case "$bank" in ''|*[!0-9]*) ;; *) printf '%s\n' "$bank" >> "$brefs";; esac   # numeric bank ref only
done < "$drv"
rm -f "$bodyf" "$ctx" "$drv"
# hits: bump — a bank question that justified an inferred answer this grill has fired (§2.6, SHAPE.md).
# Reuse-rate is the risk-1 / D13 signal, so bump each referenced entry once and stamp its date.
# ponytail: single-tier bump — refs index one file. Two-tier upgrade (paired with the merged read
#   above): with G = `grep -c '^### ' $TL_HOME/lead/questions.md`, split refs by offset —
#   bump_hits global-file <refs ≤ G>; bump_hits project-file <(refs > G) each minus G>. bump_hits
#   ignores out-of-range ordinals, so a global ref firing in X lands in the global file, not X's.
if [ -s "$brefs" ]; then bump_hits "$TL_LEAD/questions.md" $(sort -un "$brefs"); fi
rm -f "$brefs"
"$BIN/tl-metric.sh" record "$id" grill "$(( $(date +%s) - t0 ))" || true   # D13 input (E1.5)
_finalize "$id"
