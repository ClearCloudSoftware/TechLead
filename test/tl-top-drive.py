#!/usr/bin/env python3
"""tl-top-drive.py — run ONE tl-top scenario in a pty and assert on what it painted.

Called by tl-top-views-smoke.sh, once per scenario, each against a fresh fixture. Keeping the key
sequences short and independent is the point: one long session couples every step to the ones
before it (an extra row shifts a cursor move, an undismissed pause eats the next key), and then a
failure anywhere reads as a failure everywhere.

NOTE when adding assertions: curses repaints only the cells that CHANGED, so what arrives here is a
stream of edits, not a screenshot. Text already on screen in the same position is not re-emitted —
switching view 3 -> 1 sends just the moved brackets, not "[1 inbox]". Assert on content the new
screen genuinely brings with it.

usage: tl-top-drive.py <repo> <render|answer|grill-ok|grill-fail>
"""
import fcntl
import os
import pty
import re
import select
import struct
import subprocess
import sys
import signal
import termios
import time

REPO, SCENARIO = sys.argv[1], sys.argv[2]
ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][A-B0-9]|\x1b[=>]|\x1b\][^\x07]*\x07")
ROWS, COLS = 40, 120

master, slave = pty.openpty()
fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
env = dict(os.environ, TERM="xterm", LINES=str(ROWS), COLUMNS=str(COLS))
proc = subprocess.Popen([sys.executable, os.path.join(REPO, "bin", "tl-top")],
                        stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
os.close(slave)

bad = []


def drain(seconds=1.5):
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


def send(keys, wait=1.5):
    if proc.poll() is not None:
        bad.append("tl-top exited (%s) before it could be sent %r" % (proc.returncode, keys))
        return ""
    os.write(master, keys.encode())
    screen = drain(wait)
    if os.environ.get("TL_DRIVE_DEBUG"):     # see what it actually painted, not what you assume
        print("--- %s after %r ---\n%s" % (SCENARIO, keys, screen), file=sys.stderr)
    return screen


def want(screen, needle, label):
    if needle.lower() not in screen.lower():
        bad.append("%s: expected %r on screen" % (label, needle))


def expect(needle, label, seed="", timeout=8.0):
    """Keep draining until `needle` appears, or give up after `timeout`.

    Use this after anything that shells out. A shelled command takes a variable moment — a grill
    driver, a metric write, a repaint — so a fixed drain window turns the assertion into a race
    that fails a few percent of the time for no reason. Returns everything seen."""
    acc, end = seed, time.time() + timeout
    while needle.lower() not in acc.lower() and time.time() < end:
        acc += drain(0.5)
    if needle.lower() not in acc.lower():
        bad.append("%s: expected %r within %.0fs" % (label, needle, timeout))
    return acc


# Wait for the first paint to COMPLETE rather than guessing a duration: startup shells out to
# tl-state once per task, plus tl-backlog and tl-project, so the time before anything appears grows
# with the fixture. The footer is drawn last, so its presence means the screen is fully emitted.
launch = expect("q quit", "tl-top must paint a first screen", seed=drain(1.0), timeout=15)

if SCENARIO == "render":
    want(launch, "[1 inbox]", "launch")
    want(launch, "tl-add-search", "launch")
    want(launch, "never grilled", "launch: an un-grilled backlog item must show")
    want(launch, "csv-export", "launch")
    want(launch, "already decided here", "launch: the pane counts what is settled")
    # a long question must WRAP, not be clipped at the window edge
    want(launch, "services already depending on it?", "launch: long question must wrap in the pane")
    if launch.count("● question") != 2:
        bad.append("launch: two question rows expected (q2, q3 open; q1 is not) — got %d"
                   % launch.count("● question"))

    # the fallback row types keep their text ONLY in `detail`; the pane must render it
    screen = send("jj")                       # past both question rows, onto the parked worker
    want(screen, "worker asks", "a parked worker must produce a decision row")
    want(screen, "depend on it?", "inbox: a decision row's question must wrap in the pane")
    want(screen, "tl/tl-oauth", "inbox: a dispatched row must name its branch")
    want(screen, "worktree", "inbox: ...and its worktree")
    want(screen, "worktree gone", "a released worktree is called out, not silently blank")
    want(screen, "started", "a dispatched row must say how long it has been going")
    want(screen, "last output", "...and when its session last wrote")
    send("kk")

    screen = send("2")
    want(screen, "open question", "view 2 briefing")
    want(screen, "services already depending on it?", "view 2 must wrap the question")
    want(screen, "more — 3 modal", "view 2 must cap prior answers and say how many it held back")
    want(screen, "backlog said", "view 2 must keep room for what the backlog asked for")

    screen = send("3")
    want(screen, "techlead >", "view 3 modal")
    screen = send(":fleet\n")
    want(screen, "branch", "':fleet' must have a BRANCH column")
    want(screen, "tl/tl-oauth", "':fleet' must show the branch")
    screen = send(":q add-search\n")
    want(screen, "q1", "view 3 ':q' lists answered questions too")
    screen = send("j" * 20)                   # q2 (the long one) is last in file order
    want(screen, "services already depending on it?", "view 3 pane must wrap the question")
    want(send("?"), "renders, never mutates", "help overlay")
    send(" ")

elif SCENARIO == "answer":
    screen = send("d")
    want(screen, "answer q2", "answer prompt opens")
    want(screen, "what happens to the old index", "the prompt label carries the question")
    want(screen, "enter commit", "the prompt shows its keys")
    send("use the existing index; drop the old one behind a flag\n", 3.0)
    # THE RHYTHM: the answered row vanishes, the next open question is already selected, and `d`
    # must act on it at once. A result notice that consumes the keypress costs a key exactly here.
    expect("answer q3", "d must act immediately after an answer — the notice must not eat it",
           seed=send("d", 1.0))
    send("\x1b")                              # esc: leave q3 open, writing nothing

elif SCENARIO == "worktrees":
    # The one thing the queue structurally cannot show: a worktree with no task. It blocks its id
    # from ever being re-spawned, and having no meta it is not a row anywhere else.
    send("3")
    screen = send(":worktrees\n")
    want(screen, "tl-orphan", "an unclaimed worktree must be listed")
    want(screen, "orphan", "...and named as one")
    want(screen, "refuse", "...saying it blocks tl-spawn")
    want(screen, "tl-docs", "a live worktree is listed too")
    screen = send("/orphan\n")
    # assert on fragments that cannot straddle a wrap: the pane wraps, so "worktree remove" is
    # split across lines exactly when the path in front of it is long — which is always
    want(screen, "git -C", "the detail pane must carry the command that clears it")
    want(screen, "refuses if it is dirty", "...and say git will not delete uncommitted work")

elif SCENARIO == "watch":
    # A dispatched task used to collapse into a one-line summary at the bottom — the one thing you
    # were waiting on was the one thing you could not watch.
    want(launch, "◐ working", "a running worker must be a row, not a footnote")
    want(launch, "tl-worker", "...named")
    want(launch, "last output", "...saying when it last made a sound")
    # and the reason every task comes out as a `plan` has to be said, not left to be discovered
    want(launch, "readiness: survey", "survey readiness must explain itself")
    want(launch, "tl-scaffold-test", "...and point at the way out")

    screen = send("/tl-worker\n")             # not /worker: that also matches "worker asks…"
    want(screen, "tl-worker", "filter to the running task")
    screen = send("p", 2.5)                   # follow its log rather than snapshot it
    want(screen, "following", "p on a running worker must follow, not snapshot")
    want(screen, "editing src/config.py", "...showing the session log")
    # A literal ^C cannot be tested here: this pty has no controlling terminal (Popen does not
    # setsid + TIOCSCTTY), so the kernel never turns the byte into SIGINT — it just echoes ^C.
    # Signalling the process directly exercises the same handler the real ctrl-c reaches.
    os.kill(proc.pid, signal.SIGINT)
    expect("WHAT", "interrupting the follow must return to the TUI", seed=drain(2.0))

elif SCENARIO == "report":
    # "plan report ready: approve, skip or fix" has to be actionable FROM HERE — the row was
    # telling you to do something the TUI gave you no way to do.
    screen = send("/docs\n")
    want(screen, "tl-docs", "filter to the finished plan")
    want(screen, "public re-export", "the report itself must show in the pane, not the session log")
    screen = send("2")
    want(screen, "report", "view 2 must label the report")
    want(screen, "rename the widget module", "view 2 must show the report")
    send("1")
    screen = send("p", 2.5)
    want(screen, "update the three importers", "p must page the REPORT")
    screen = send("g")
    want(screen, "approve / skip / fix", "g on a plan must offer the plan gate, not the change one")
    # assert on the OUTCOME rather than the confirm text: the prompt overlaps the footer it
    # replaces, so curses re-emits only fragments of it. The shell checks meta for `approval`.
    send("y", 2.0)                            # confirm -> tl-approve runs full-screen
    send("\n", 1.5)                           # its "approve / skip / fix ?" -> default approve
    screen = expect("recorded your decision", "the outcome must be reported back in the TUI",
                    seed=send("\n", 1.0))
    # THE REPORTED BUG: approving changed nothing, so the row went on saying "approve, skip or
    # fix" — the decision you had just made. It must now show as signed off and retirable.
    # Assert against the ACCUMULATED stream: the row repaints in the same breath as the notice, so
    # a fresh drain here sees nothing (curses only re-emits what changed).
    want(screen, "t to retire", "an approved plan must flip to a retire row")
    expect("t retire (frees", "...and the footer must offer teardown", seed=send(" "))
    send("t")
    send("y", 3.0)                            # confirm -> tl-teardown releases the worktree
    expect("retired", "teardown must report back", seed=send("\n", 1.0))

elif SCENARIO == "grill-ok":
    screen = send("/backlog\n")
    want(screen, "csv-export", "filter down to the un-grilled items")
    screen = send("g")
    want(screen, "tl-grill csv-export", "g on a backlog row must offer to grill it")
    want(screen, "no worker is dispatched", "...and say it does not dispatch")
    send("y", 3.0)                            # confirm; the grill runs full-screen, then pauses
    expect("grilled", "a successful grill must say so in the TUI", seed=send("\n", 1.0))

elif SCENARIO == "grill-fail":
    # A FAILED command must not look like one that did nothing. This is why g/r felt broken:
    # tl-grill exits 1 before doing any work when it has no driver, the error scrolls past, and
    # the TUI comes back untouched.
    screen = send("/dark\n")
    want(screen, "dark-mode", "filter to the item whose grill will fail")
    send("g")
    send("y", 3.0)                            # confirm; the grill fails, then pauses on the shell
    screen = expect("exited 1", "a failed shell-out must be reported in the TUI",
                    seed=send("\n", 1.0))
    want(screen, "nothing changed", "...and say that nothing changed")
    send(" ")
    screen = send("/\n")                      # `/` then enter clears the filter (it is not seeded)
    want(screen, "tl-add-search", "an empty / must clear the filter, bringing the rows back")

else:
    bad.append("unknown scenario %r" % SCENARIO)

send("q", 1.0)
try:
    proc.wait(timeout=5)
except subprocess.TimeoutExpired:
    proc.kill()
    bad.append("quit: 'q' did not exit — the UI was left in a prompt or a pause")
if proc.returncode not in (0, None):
    bad.append("exit code %r (a traceback in a view lands here)" % proc.returncode)

for b in bad:
    print("FAIL[%s]: %s" % (SCENARIO, b))
sys.exit(1 if bad else 0)
