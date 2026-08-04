# Tutorial: Build a Todo App with TechLead + a Local Model

This walks you through using TechLead — running **entirely on a local model** (opencode +
`qwen3-coder:30b`, so **$0** and offline) — to build a small `todo` CLI, one feature at a time,
each going through the full loop: **backlog → grill → spec → brief → change → gate → deliver**.

> **Honest framing.** TechLead is built for *brownfield* work — its value is judgment and context
> on a codebase too big to hold in your head (§2.7). A todo app is greenfield, where a plain agent
> would also do fine. Use this tutorial to learn the **workflow and the guardrails**; the payoff
> comes later when you point it at a real, messy repo. Also: a local 30B model is **slow** (minutes
> per task) and grills **coarsely** — fine for learning, and you'll see where you'd reach for a
> stronger model.

## Prerequisites

- TechLead checked out; `bash`, `git`, `jq`
- [opencode](https://opencode.ai) + [ollama](https://ollama.com), with a tools-capable coding model
- `python3` (for the example app)

Verify the model works headlessly:

```sh
ollama list | grep qwen3-coder                       # is it pulled?
opencode run "reply with: ok" --model ollama/qwen3-coder:30b   # prints: ok
```

If you don't have it: `ollama pull qwen3-coder:30b`. (Any tools-capable coding model works; see
`docs/USAGE.md` for why `qwen3-coder` is the local pick.)

---

## Step 1 — Point TechLead at the local model

```sh
cd /path/to/techlead
export TL_HOME="$PWD"
export PATH="$PWD/bin:$PATH"

# configure the instance once, with the wizard: pick `opencode` as the harness and
# `ollama/qwen3-coder:30b` as the model when asked, and say yes to seeding the lead/ skeleton.
tl-init.sh
```

`tl-init` writes `config/instance.env` (the worker + grill adapters and the model), which every
`tl-*` command auto-loads — so you don't re-export anything each shell — and scaffolds `lead/` as
empty stubs.

The grill needs a **question bank** — your judgment, the questions you'd actually ask. `tl-init`
left `lead/questions.md` as an empty stub; fill it (you'd grow this from real grills over time —
that's the `lead/` judgment layer):

```sh
cat > "$TL_HOME/lead/questions.md" <<'EOF'
# questions.md — grill question bank
- What is the blast radius if this ships half-done?
- Which existing pattern should this follow, and is it current or deprecated?
- What must be true for this to be "done"?
- Is there a simpler version that still covers the need?
- What breaks if two of these features are built at once?
EOF
```

---

## Step 2 — Scaffold the todo project and register it

TechLead works on a *registered* project with a **test baseline** (so a `change` compares against
known-failing, not against green). Create the app as a stub plus a test script that prints one
failing-check id per broken behavior — that's the contract `tl-gate` expects.

> **Where projects live.** By convention managed repos sit under **`$TL_HOME/projects/`** (§3.2 — the
> lead is read-only there). But TechLead registers a project by its **absolute path**, so it can live
> anywhere you keep repos; just point the registry at it. Note `TL_HOME` is *TechLead's own checkout*,
> **not** your OS `$HOME` — don't confuse the two.

```sh
mkdir -p "$TL_HOME/projects"
APP="$TL_HOME/projects/todo"               # or your own projects folder, e.g. ~/projects/todo
mkdir -p "$APP"; cd "$APP"

# a stub CLI — does nothing yet; TechLead will fill it in
cat > todo.py <<'EOF'
#!/usr/bin/env python3
import sys
def main():
    print("usage: todo [add TEXT | list | done N]")
if __name__ == "__main__":
    main()
EOF

# the test command: run behaviors, echo an id for each one that FAILS (one per line)
cat > test.sh <<'EOF'
#!/bin/sh
D=$(mktemp -d); export TODO_FILE="$D/todos.txt"
python3 todo.py add "buy milk" >/dev/null 2>&1
python3 todo.py list 2>/dev/null | grep -q "buy milk" || echo feat-add
python3 todo.py done 1 >/dev/null 2>&1
python3 todo.py list 2>/dev/null | grep -Eq "x|done|✓" || echo feat-done
rm -rf "$D"; exit 0
EOF
chmod +x test.sh

git init -q -b main && git add -A && git commit -q -m "stub: todo CLI + tests"
```

Register it and capture the baseline with the wizard (with the stub, **everything fails** — that's
the starting point TechLead will improve on):

```sh
cd "$TL_HOME"
tl-onboard.sh "$APP"
# It detects branch=main and mode=local-only — accept those. It can't guess our custom runner, so
# when asked enter the test command `sh test.sh`, set max files to `5`, and say yes to capturing the
# baseline (records feat-add, feat-done as known-failing). Decline the survey offer — we'll grill
# features directly. Registered as `todo` at readiness=ready.
```

> **Greenfield vs brownfield.** We wrote `test.sh` first, so `tl-onboard` can baseline it and
> register at `ready` (change tasks allowed). A *truly empty* project would instead use
> `tl-new todo`, which registers at `survey` (plan-only) until an early plan task builds a test
> harness — then `tl-baseline` promotes it to `ready`.

---

## Step 3 — Write the backlog

`data/backlog.md` is your plain-markdown queue, one item per `## slug: title` heading:

```sh
cat > "$TL_HOME/data/backlog.md" <<'EOF'
# Backlog

## add-list: Add and list todos
`todo add "text"` appends a task; `todo list` prints tasks with a 1-based index.
Persist tasks to the file named by the TODO_FILE env var (default ~/.todos). Small, self-contained.

## mark-done: Mark a todo complete
`todo done N` marks task N complete; `todo list` shows completed tasks with an `[x]` marker.
Builds on add-list.

## rewrite-in-rust: Rewrite the whole thing in Rust for speed
EOF
```

(That third item is bait — we'll let the grill reject it in Step 6.)

---

## Step 4 — Build the first feature with `tl-run`

`tl-run <slug>` walks the whole pipeline — grill → brief → spawn → gate → deliver — and **stops only
at the two points where your judgment decides the outcome**. Everything else is automatic, and it
never babysits the worker. (It's a thin wrapper over the individual `tl-*` commands, which still work
by hand — see `docs/USAGE.md`; the manual path is always the fallback.)

### First pass — grill, then spawn

```sh
tl-run.sh add-list
```

This grills `add-list` into a spec. **Stop 1 — spec approval:** if the grill leaves any question
`open`, `tl-run` halts and shows it — it never guesses your answer. On a small task qwen3-coder
usually infers everything (0 open) and auto-advances to brief → spawn, then **returns**, leaving the
worker running in an isolated worktree on branch `tl/tl-add-list`. If it *did* leave one open, answer
it and re-run — `tl-run` picks up where it left off:

```sh
tl-grill.sh answer tl-add-list q2 decided "index is 1-based; one task per line"
tl-run.sh add-list                # resumes: brief → spawn → returns
```

### Supervise (don't babysit)

`tl-run` handed off and returned; the worker runs in the background. Watch if you like:

```sh
tl-watch.sh --once                # or leave `tl-watch.sh` running; zero tokens while idle
tl-peek.sh  tl-add-list 20        # what the model is doing
tl-state.sh tl-add-list           # working | done | failed
```

On a local model this takes a few minutes.

### Second pass — gate and deliver

When `tl-state.sh tl-add-list` says `done`, run the **same command** again. `tl-run` recomputes where
the pipeline is and resumes at the gate:

```sh
tl-run.sh add-list
```

**Stop 2 — gate findings:** it runs the tests vs the baseline plus the scope/danger checks. If any
`ask-user` finding is unresolved it halts with the findings and the three resolutions
(approve / skip / fix) and merges nothing. A clean feature ff-merges straight onto `main`. Check it:

```sh
cd "$APP"
TODO_FILE=/tmp/t python3 todo.py add "buy milk" && TODO_FILE=/tmp/t python3 todo.py list
cd "$TL_HOME"
```

> **Resumable, no hidden state.** `tl-run` keeps no progress of its own — it recomputes the stage from
> the spec, brief, task meta, and `tl-state` every run. Kill it, re-run it, or drop back to the manual
> `tl-grill`/`tl-brief`/`tl-spawn`/`tl-deliver` commands at any point; it always continues from where
> the pipeline actually is.

---

## Step 5 — Build the second feature

Same one command, now that `add-list` has landed:

```sh
tl-run.sh mark-done               # grill → (answer any open) → brief → spawn → returns
# ... wait for the worker: tl-state.sh tl-mark-done → done, then:
tl-run.sh mark-done               # resumes at the gate → deliver
```

Because the baseline already knew `feat-done` was failing, fixing it is **not** a regression — the
gate passes. If `mark-done` had broken `feat-add`, that *would* show as a regression and `tl-run`
would halt at the gate, merging nothing. That's the point of the baseline.

---

## Step 6 — Let the lead say "no"

The most senior move is refusing work. `tl-run` on the bait item grills it and **halts at the spec
stop**; reject it there and nothing is ever dispatched:

```sh
tl-run.sh   rewrite-in-rust               # grills, then halts at the spec (an open question)
tl-grill.sh reject tl-rewrite-in-rust "Premature — no perf problem exists; revisit if profiling shows one"
tl-run.sh   rewrite-in-rust               # now halts: "rejected — nothing dispatched"
```

The reason is recorded against the backlog (`data/backlog.decisions`), and no worker is ever
spawned. That refusal — not the code — is what makes it a *tech lead* and not an order-taker.

---

## Step 7 — See whether it's paying off (the kill-gate metric)

TechLead has been quietly timing itself the whole way. Every grill and every approval wrote a row to
`data/metrics.tsv` — no setup, it just happens. That feeds the **kill-gate** (D13): the honest check
of whether supervising the agent actually costs you *less* time than doing the work yourself.

There's one number it can't measure — how long *you'd* have taken by hand. Only you know that, so log
your honest estimate per feature (`tl-approve` also nudges you after a manual approval):

```sh
tl-metric.sh record tl-add-list  self 900     # ~15 min if you'd hand-written it
tl-metric.sh record tl-mark-done self 600     # ~10 min
```

Then read the ledger:

```sh
tl-metric.sh report
```

```
feature              grill_s   approve_s    net_s   self_s verdict
tl-add-list              120          30      150      900 faster ✓
tl-mark-done              90          25      115      600 faster ✓
```

`net_s` is your total time on the loop (grill + approve); `verdict` compares it to `self_s`. A column
of `faster ✓` means the supervision is buying you time; a wall of `slower ✗` is the gate telling you
to stop or shrink the tool. On a real repo you'd read this alongside the reuse counters in
`lead/principles.md` at ~feature 15 and make the continue/stop call with data, not a hunch.

> **Two features isn't the verdict.** This is the *mechanism*, shown early so you know it's there. The
> real kill-gate reads ~15 features — enough for the numbers to mean something.

---

## Running a small crew

Independent features can run in parallel. Spawn two, then let the watcher supervise both:

```sh
tl-spawn.sh --id a --project "$APP" --project-name todo --kind change --brief .../brief-a.md
tl-spawn.sh --id b --project "$APP" --project-name todo --kind change --brief .../brief-b.md
tl-watch.sh      # wakes you only when one needs a decision or is ready; zero tokens while idle
```

> **Local-model caveat:** two workers on one local model contend for the same GPU, so they
> effectively **serialize** — you get supervision benefits, not speed. Real parallelism needs
> either separate machines or a hosted/API model (point `TL_OPENCODE_MODEL` or `TL_WORKER_CMD` at
> one — no other change).

---

## Tips for local models

- **Keep features tiny** — one file, one behavior. Local models do far better on tight scope.
- **Grills are coarse.** qwen3-coder marks nearly everything `decided`; for sharper questions,
  point `TL_OPENCODE_MODEL` at an `opencode/*-free` or cloud model just for the grill.
- **Be patient / watch with `tl-peek`.** Minutes per task is normal.
- **Re-baseline after milestones:** `tl-baseline.sh todo` once several features have landed, so the
  known-failing set stays accurate (a stale baseline turns old failures into fake regressions).
- **Cost is `$0`** and everything is offline.

---

## What you just did

You drove a real project through TechLead's full lifecycle — spec'd by a grill, briefed, built by
an autonomous worker in an isolated worktree, supervised for zero idle cost, gated against a test
baseline with scope/danger guards, and fast-forward-merged — **entirely on a free local model**.

The same commands work against a real brownfield repo; there, the parts that felt like ceremony
here (the grill's questions, the baseline, danger paths, the "no") are exactly what stop an
autonomous agent from confidently doing the wrong thing. Swap the model or harness any time by
changing one env var — see `docs/USAGE.md`.
