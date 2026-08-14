#!/usr/bin/env bash
# tl-top-views-smoke.sh — drive the REAL curses UI in a pty (no agent, zero tokens).
#
# tl-top-smoke.sh covers the pure model; nothing there ever executes a draw function, so a typo in
# a view only surfaces when the owner presses the key. This builds a fixture instance, then runs
# tl-top against it and asserts on what it painted.
#
# Each SCENARIO gets a FRESH fixture and its own tl-top process (test/tl-top-drive.py). That is
# deliberate: one long key sequence couples every step to the ones before it — an extra row shifts
# a cursor move, an undismissed pause eats the next key — and a failure anywhere then reads as a
# failure everywhere. Short independent runs cost a few processes and localise the blame.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
KIDS=""
trap 'for k in $KIDS; do kill $k 2>/dev/null || true; done; rm -rf "$WORK"' EXIT

export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_LEAD="$WORK/lead"
export TL_WORKTREES="$WORK/state/wt" TL_BACKLOG="$WORK/data/backlog.md"
export TL_TOP_INTERVAL=1 TL_FRESH_SECS=0
export PAGER=cat   # so `p` does not block the pty on an interactive pager

# A grill driver that succeeds normally but FAILS for 'dark-mode', so a shelled command that exits
# non-zero can be told apart from one that quietly did nothing.
cat > "$WORK/grill-driver.sh" <<EOF
#!/usr/bin/env bash
[ "\${TL_GRILL_SLUG:-}" = dark-mode ] && { echo "boom: no grill driver" >&2; exit 1; }
exec "$REPO/test/demo-grill.sh"
EOF
chmod +x "$WORK/grill-driver.sh"
export TL_GRILL_CMD="$WORK/grill-driver.sh"

LONG_Q="What happens to the old index while the new one builds, and who owns the rollback if the migration has to be abandoned halfway through a busy weekday afternoon with three other services already depending on it?"
WORKER_Q="Should I reuse the existing retry helper in net/retry.go, which already handles exponential backoff but not jitter, or add jitter to it and risk changing the timing for the three callers that already depend on it?"

setup() {
  rm -rf "$WORK/data" "$WORK/state" "$WORK/lead"
  mkdir -p "$TL_DATA/tl-add-search" "$TL_DATA/tl-oauth" "$TL_STATE/sessions/tl-oauth" "$TL_LEAD"

  cat > "$TL_BACKLOG" <<'EOF'
# Backlog

## add-search: Add full-text search
Filter notes by title and body. Should feel instant.

## csv-export: Export notes to CSV

## dark-mode: Dark mode
EOF

  # q1 answered (reachable only from view 3); q2 + q3 open, so the answer-then-answer rhythm is
  # exercised; q4..q11 long and answered, so the briefing has to budget them.
  {
    printf -- '---\nid: tl-add-search\nbacklog: add-search\ntitle: Add full-text search\n'
    printf 'state: drafted\ngrilled_at: 2026-08-14\noutcome:\n'
    printf 'q: q1|decided|inferred|2026-08-14|use the existing pg index, no new service\n'
    printf 'q: q3|open|owner|2026-08-14|Who signs off the index rebuild window?\n'
    for n in 4 5 6 7 8 9 10 11; do
      printf 'q: q%s|decided|inferred|2026-08-14|Answer %s - long on purpose: it wraps to three lines at a hundred and twenty columns, so nine together cannot fit a forty-row screen, which is the case the briefing has to budget for rather than silently drop the backlog.\n' "$n" "$n"
    done
    printf 'q: q2|open|inferred|2026-08-14|%s\n' "$LONG_Q"
    printf -- '---\n# Add full-text search\n'
  } > "$TL_DATA/tl-add-search/spec.md"

  # A worker parked on a decision: a live session (kill -0 on the pid) plus a stale log is what
  # tl-state reconciles into `needs-decision`. Its question is long, and this row type keeps its
  # text ONLY in `detail`, so the pane is the one place it can be read at all.
  sleep 120 &
  KIDS="$KIDS $!"
  echo "$!" > "$TL_STATE/sessions/tl-oauth/pid"
  : > "$TL_STATE/sessions/tl-oauth/log"
  printf 'kind=change\npname=notes-app\nbranch=tl/tl-oauth\nworktree=%s\nbase=deadbee\n' \
    "$WORK/wt/tl-oauth" > "$TL_STATE/tl-oauth.meta"
  printf '%s\tneeds-decision\n' "$(date +%s)" > "$TL_STATE/tl-oauth.status"
  printf 'question=%s\ndefault=yes\ntimeout=30\n' "$WORKER_Q" > "$TL_DATA/tl-oauth/ask"

  # a finished PLAN: its report IS the deliverable, and the row that says "approve, skip or fix"
  # is asking about that text. No session -> tl-state reconciles to `done` from the report.
  mkdir -p "$TL_DATA/tl-docs"
  cat > "$TL_DATA/tl-docs/report.md" <<'EOF'
# Plan: rename the widget module

1. Move widget.py to widgets/core.py
2. Update the three importers
Risk: the public re-export in __init__.py is the thing that will bite.
EOF
  # a REAL git project + worktree for it, so tl-teardown's guards and its worktree release
  # actually run rather than being taken on trust
  PROJ="$WORK/proj"
  rm -rf "$PROJ"; mkdir -p "$PROJ"
  git -C "$PROJ" init -q
  git -C "$PROJ" config user.email t@t; git -C "$PROJ" config user.name t
  echo hi > "$PROJ/a.txt"; git -C "$PROJ" add -A; git -C "$PROJ" commit -qm init
  git -C "$PROJ" worktree add -q --detach "$TL_WORKTREES/tl-docs" >/dev/null 2>&1
  git -C "$TL_WORKTREES/tl-docs" checkout -q -b tl/tl-docs
  printf 'kind=plan\npname=notes-app\nproject=%s\nworktree=%s\nbranch=tl/tl-docs\nbase=%s\nreport=%s\n' \
    "$PROJ" "$TL_WORKTREES/tl-docs" "$(git -C "$PROJ" rev-parse HEAD)" "$TL_DATA/tl-docs/report.md" \
    > "$TL_STATE/tl-docs.meta"

  # a project registered at readiness=survey — which is WHY every task spawns as a plan, and the
  # thing the TUI has to say out loud rather than leave you guessing
  mkdir -p "$TL_DATA/projects"
  printf 'path=%s\nmode=local-only\ndefault_branch=main\nmax_files_changed=25\nreadiness=survey\n' \
    "$PROJ" > "$TL_DATA/projects/notes.conf"

  # a worker actually RUNNING: live session, fresh log, no status event -> tl-state says `working`
  mkdir -p "$TL_STATE/sessions/tl-worker" "$TL_DATA/tl-worker"
  sleep 120 &
  KIDS="$KIDS $!"
  echo "$!" > "$TL_STATE/sessions/tl-worker/pid"
  printf 'reading src/notes.py\nediting src/config.py\nrunning test.sh\n' \
    > "$TL_STATE/sessions/tl-worker/log"
  printf 'kind=change\npname=notes-app\nbranch=tl/tl-worker\n' > "$TL_STATE/tl-worker.meta"

  # a REAL orphan: a worktree directory with no task claiming it. tl_worktree_acquire refuses when
  # the path exists, so this permanently blocks `tl-orphan` from being re-spawned — and it has no
  # meta, so nothing in the queue can show you the thing that is blocking you.
  git -C "$PROJ" worktree add -q --detach "$TL_WORKTREES/tl-orphan" >/dev/null 2>&1

  printf '# questions.md\n\n### what breaks that already works?\nhits: 4   last: 2026-08-14\n_scar:_ the 2024 reindex silently dropped 11k rows\n' > "$TL_LEAD/questions.md"
}

drive() { python3 "$REPO/test/tl-top-drive.py" "$REPO" "$1"; }

# ---------------------------------------------------------------------------- scenarios
setup; drive render     || fail "scenario 'render' (see above)"
echo "  S1 ok — three views paint; long prose wraps in all of them; branch/worktree/liveness shown"

setup; drive answer     || fail "scenario 'answer' (see above)"
grep -q '^q: q2|decided|owner|' "$TL_DATA/tl-add-search/spec.md" \
  || fail "S2: the answer never reached spec.md — got: $(grep '^q: q2' "$TL_DATA/tl-add-search/spec.md")"
grep -q 'drop the old one behind a flag' "$TL_DATA/tl-add-search/spec.md" \
  || fail "S2: the typed text is not in spec.md"
grep -q '^q: q1|decided|inferred|' "$TL_DATA/tl-add-search/spec.md" \
  || fail "S2: answering q2 disturbed q1"
grep -q '^q: q3|open|' "$TL_DATA/tl-add-search/spec.md" \
  || fail "S2: esc at the prompt must write nothing — q3 should still be open"
[ "$("$REPO/bin/tl-spec.sh" open-count tl-add-search)" -eq 1 ] \
  || fail "S2: expected exactly q3 still open"
grep -q 'tl-add-search' "$TL_DATA/metrics.tsv" 2>/dev/null \
  || fail "S2: tl-grill's D13 metric did not fire — tl-top bypassed the command path"
echo "  S2 ok — d answers through the real tl-grill, and the next question is answerable at once"

setup; drive worktrees  || fail "scenario 'worktrees' (see above)"
echo "  S7 ok — :worktrees surfaces the orphan that blocks a re-spawn, with the command to clear it"

setup; drive watch      || fail "scenario 'watch' (see above)"
echo "  S6 ok — a running worker is a row you can watch, and survey readiness explains itself"

setup; drive report     || fail "scenario 'report' (see above)"
grep -q '^approval=approve' "$TL_STATE/tl-docs.meta" \
  || fail "S5: g on a plan did not reach tl-approve — meta has: $(grep approval "$TL_STATE/tl-docs.meta" || echo none)"
grep -q '^state=done' "$TL_STATE/tl-docs.meta" \
  || fail "S5: t did not retire the task — meta has: $(grep '^state=' "$TL_STATE/tl-docs.meta" || echo none)"
[ ! -d "$TL_WORKTREES/tl-docs" ] || fail "S5: teardown left the worktree behind at $TL_WORKTREES/tl-docs"
echo "  S5 ok — a plan's report is readable in the TUI, and g offers the right gate for its kind"

setup; drive grill-ok   || fail "scenario 'grill-ok' (see above)"
grep -q '^q: q2|open|' "$TL_DATA/tl-csv-export/spec.md" 2>/dev/null \
  || fail "S3: 'g' did not grill the backlog item — no spec at $TL_DATA/tl-csv-export/spec.md"
[ ! -f "$TL_STATE/tl-csv-export.meta" ] \
  || fail "S3: grilling must NOT dispatch a worker — that is what 'r' is for"
echo "  S3 ok — g grilled an un-grilled backlog item, and dispatched nothing"

setup; drive grill-fail || fail "scenario 'grill-fail' (see above)"
# tl-grill must FAIL CLOSED when its driver dies: the spec stays drafted with no questions, rather
# than being marked `specified` (which reads as "ready to dispatch") because a dead driver produced
# an empty question list.
grep -q '^state: drafted' "$TL_DATA/tl-dark-mode/spec.md" \
  || fail "S4: a failed grill left the spec as: $(grep '^state:' "$TL_DATA/tl-dark-mode/spec.md")"
grep -q '^q: ' "$TL_DATA/tl-dark-mode/spec.md" && fail "S4: a failed grill recorded questions" || true
echo "  S4 ok — a command that exits non-zero is reported, and the grill fails closed"

echo "PASS: tl-top renders, answers, grills, and reports a failed command"
