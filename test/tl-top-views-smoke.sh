#!/usr/bin/env bash
# tl-top-views-smoke.sh — drive the REAL curses UI in a pty (no agent, zero tokens).
#
# tl-top-smoke.sh covers the pure model; nothing there ever executes a draw function, so a typo in
# a view only surfaces when the owner presses the key. This starts tl-top on a fixture instance,
# sends keystrokes, and asserts on what it painted — including one end-to-end answer, which goes
# through the prompt widget and out to the real `tl-grill answer`, exactly as it does in use.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_LEAD="$WORK/lead"
export TL_WORKTREES="$WORK/state/wt" TL_BACKLOG="$WORK/data/backlog.md"
export TL_TOP_INTERVAL=1 TL_GRILL_CMD="$REPO/test/demo-grill.sh"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$TL_DATA/tl-add-search" "$TL_STATE" "$TL_LEAD"

cat > "$TL_BACKLOG" <<'EOF'
# Backlog

## add-search: Add full-text search
Filter notes by title and body. Should feel instant.

## csv-export: Export notes to CSV
EOF

# a grilled item: one inferred answer (reachable only from view 3) + one open question (the inbox row)
cat > "$TL_DATA/tl-add-search/spec.md" <<'EOF'
---
id: tl-add-search
backlog: add-search
title: Add full-text search
state: drafted
grilled_at: 2026-08-14
outcome:
q: q1|decided|inferred|2026-08-14|use the existing pg index, no new service
q: q4|decided|inferred|2026-08-14|Answer 4 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q5|decided|inferred|2026-08-14|Answer 5 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q6|decided|inferred|2026-08-14|Answer 6 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q7|decided|inferred|2026-08-14|Answer 7 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q8|decided|inferred|2026-08-14|Answer 8 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q9|decided|inferred|2026-08-14|Answer 9 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q10|decided|inferred|2026-08-14|Answer 10 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q11|decided|inferred|2026-08-14|Answer 11 - this one runs long on purpose: it has to wrap to three lines at a hundred and twenty columns so that nine of them together cannot fit on a forty-row screen, which is exactly the case the briefing has to budget for rather than silently drop the backlog.
q: q3|open|inferred|2026-08-14|What happens to the old index while the new one builds, and who owns the rollback if the migration has to be abandoned halfway through a busy weekday afternoon with three other services already depending on it?
---
# Add full-text search
EOF

# A worker parked on a decision, asking a LONG question. This row type keeps its text only in
# `detail` — there is no spec question behind it — so the inbox detail pane is the one place it can
# be read in full. Needs a live session (kill -0 on the pid) plus a stale log, which is what
# tl-state reconciles into `needs-decision`.
WORKER_Q="Should I reuse the existing retry helper in net/retry.go, which already handles exponential backoff but not jitter, or add jitter to it and risk changing the timing for the three callers that already depend on it?"
mkdir -p "$TL_STATE/sessions/tl-oauth" "$TL_DATA/tl-oauth"
sleep 120 &
SLEEP_PID=$!
disown 2>/dev/null || true
trap 'kill $SLEEP_PID 2>/dev/null; rm -rf "$WORK"' EXIT
echo "$SLEEP_PID" > "$TL_STATE/sessions/tl-oauth/pid"
: > "$TL_STATE/sessions/tl-oauth/log"
printf 'kind=change\npname=notes-app\nbranch=tl/tl-oauth\nworktree=%s\nbase=deadbee\n' \
  "$WORK/wt/tl-oauth" > "$TL_STATE/tl-oauth.meta"
printf '%s\tneeds-decision\n' "$(date +%s)" > "$TL_STATE/tl-oauth.status"
printf 'question=%s\ndefault=yes\ntimeout=30\n' "$WORKER_Q" > "$TL_DATA/tl-oauth/ask"
export TL_FRESH_SECS=0     # the log is stale by design, so tl-state reports the parked state

cat > "$TL_LEAD/questions.md" <<'EOF'
# questions.md

### what breaks that already works?
hits: 4   last: 2026-08-14
_scar:_ the 2024 reindex silently dropped 11k rows
EOF

python3 - "$REPO" <<'PY' || fail "pty drive failed (see above)"
import os, pty, re, select, struct, subprocess, sys, termios, fcntl, time

repo = sys.argv[1]
ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][A-B0-9]|\x1b[=>]|\x1b\][^\x07]*\x07")

master, slave = pty.openpty()
fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
env = dict(os.environ, TERM="xterm", LINES="40", COLUMNS="120")
p = subprocess.Popen([sys.executable, os.path.join(repo, "bin", "tl-top")],
                     stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
os.close(slave)

def drain(seconds=1.0):
    out, end = b"", time.time() + seconds
    while time.time() < end:
        r, _, _ = select.select([master], [], [], 0.1)
        if not r:
            continue
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        end = time.time() + 0.3          # keep reading while it is still painting
    return ANSI.sub("", out.decode("utf-8", "replace")).replace("\r", "")

def send(keys, wait=1.0):
    os.write(master, keys.encode())
    return drain(wait)

bad = []
def want(screen, needle, label):
    if needle.lower() not in screen.lower():
        bad.append("%s: expected %r on screen" % (label, needle))

# NOTE for anyone adding assertions here: curses repaints only the cells that CHANGED, so this is
# a stream of edits, not a screenshot. Text that is already on screen in the same position is not
# re-emitted — e.g. switching 3 -> 1 sends just the moved brackets, not "[1 inbox]". Assert on
# content the new view genuinely brings with it.

screen = drain(2.0)
want(screen, "[1 inbox]", "launch")
want(screen, "question", "launch")
want(screen, "tl-add-search", "launch")
want(screen, "q3", "launch")
want(screen, "never grilled", "launch: un-grilled backlog item must show")
want(screen, "csv-export", "launch")
want(screen, "already decided here", "launch: the detail pane counts what is settled")
# the reported bug: a long question was truncated at the window edge in all three views.
# The table row still truncates (that is what makes it a table) — the detail pane must not.
want(screen, "services already depending on it?", "launch: long question must WRAP in the pane")
if screen.count("● question") != 1:
    bad.append("launch: exactly one question row expected (q1 is answered, so it must not be a "
               "row) — got %d" % screen.count("● question"))

# the fallback row types (decision/ready/review/blocked/failed) keep their text ONLY in `detail`;
# the pane used to draw a rule and then jump straight to peek output, leaving the truncated table
# row as the only copy.
screen = send("j")
want(screen, "worker asks", "a parked worker must produce a decision row")
want(screen, "depend on it?", "inbox: a decision row's question must WRAP in the pane")
# parallel workers each have their own worktree + branch; the row has to say which
want(screen, "tl/tl-oauth", "inbox: a dispatched row must name its branch")
want(screen, "worktree", "inbox: ...and its worktree")
want(screen, "worktree gone", "a released/never-made worktree is called out, not silently blank")
send("k")

screen = send("2")
want(screen, "open question", "view 2 briefing")
# 9 answered questions, each wrapping to 2-3 lines, must not crowd out the backlog context
want(screen, "more — 3 modal", "view 2 must cap the prior answers and say how many it held back")
want(screen, "backlog said", "view 2 must keep room for what the backlog asked for")
want(screen, "services already depending on it?", "view 2 must wrap the question")
screen = send("3")
want(screen, "techlead >", "view 3 modal")
screen = send(":fleet\n", 1.5)
want(screen, "branch", "':fleet' must have a BRANCH column")
want(screen, "tl/tl-oauth", "':fleet' must show the branch")
screen = send(":q add-search\n", 1.5)
want(screen, "q1", "view 3 :q lists answered questions too")
want(screen, "inferred", "view 3 :q")
screen = send("j" * 14)                    # q3 (the long one) is the last row here
want(screen, "services already depending on it?", "view 3 detail pane must wrap the question")
want(send("?"), "renders, never mutates", "help overlay")
send(" ")                                  # dismiss help

screen = send("1")
want(screen, "WHAT", "back to view 1 repaints the inbox table")
want(screen, "never grilled", "back to view 1")
screen = send("d", 1.5)                    # answer the open question
want(screen, "answer q3", "answer prompt opens")
want(screen, "what happens to the old index", "the prompt label carries the question")
want(screen, "enter commit", "answer prompt shows its keys")
screen = send("use the existing index; drop the old one behind a flag\n", 3.0)

# an un-grilled backlog item must be grillable from here: g, confirm, and its questions land in
# the inbox to answer — without dispatching a worker, which is what `r` would do.
send(" ")                                  # the answer left a notice; it eats the next keypress
screen = send("/backlog\n", 1.5)
want(screen, "csv-export", "filter down to the un-grilled item")
screen = send("g", 1.5)
want(screen, "tl-grill csv-export", "g on a backlog row must offer to grill it")
want(screen, "no worker is dispatched", "...and say it does not dispatch")
send("y", 4.0)
send("/\n", 1.5)                            # clear the filter
screen = drain(2.0)

send("q", 1.0)
try:
    p.wait(timeout=5)
except subprocess.TimeoutExpired:
    p.kill()
    bad.append("quit: 'q' did not exit")
if p.returncode not in (0, None):
    bad.append("exit code %r (a traceback in a view would land here)" % p.returncode)

for b in bad:
    print("FAIL:", b)
sys.exit(1 if bad else 0)
PY

echo "  V1 ok — all three views painted, help overlay, prompt opened"

grep -q '^q: q3|decided|owner|' "$TL_DATA/tl-add-search/spec.md" \
  || fail "V2: the answer never reached spec.md — got: $(grep '^q: q3' "$TL_DATA/tl-add-search/spec.md")"
grep -q 'drop the old one behind a flag' "$TL_DATA/tl-add-search/spec.md" \
  || fail "V2: the typed text is not in spec.md"
grep -q '^q: q1|decided|inferred|' "$TL_DATA/tl-add-search/spec.md" \
  || fail "V2: answering q3 disturbed q1"
[ "$("$REPO/bin/tl-spec.sh" open-count tl-add-search)" -eq 0 ] \
  || fail "V2: q3 is still open after answering it"
echo "  V2 ok — the prompt's text reached spec.md through the real tl-grill answer"

grep -q 'tl-add-search' "$TL_DATA/metrics.tsv" 2>/dev/null \
  || fail "V3: tl-grill's D13 metric did not fire — tl-top bypassed the command path"
echo "  V3 ok — the command path ran (metric recorded), so its refusals still apply"

grep -q '^q: q2|open|' "$TL_DATA/tl-csv-export/spec.md" 2>/dev/null \
  || fail "V4: 'g' did not grill the backlog item — no spec at $TL_DATA/tl-csv-export/spec.md"
[ ! -f "$TL_STATE/tl-csv-export.meta" ] \
  || fail "V4: grilling must NOT dispatch a worker — that is what 'r' is for"
echo "  V4 ok — g grilled an un-grilled backlog item, and dispatched nothing"

echo "PASS: tl-top three views render, d answers a question, and g grills a backlog item"
