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

# use opencode for both the worker and the grill, on the local model
export TL_WORKER_CMD="$TL_HOME/adapters/opencode-worker.sh"
export TL_GRILL_CMD="$TL_HOME/adapters/opencode-grill.sh"
export TL_OPENCODE_MODEL="ollama/qwen3-coder:30b"
```

The grill needs a **question bank** — your judgment, the questions you'd actually ask. Seed a
starter one (you'd grow this from real grills over time — that's the `lead/` judgment layer):

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

```sh
APP="$HOME/todo-app"
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

Register it and capture the baseline (with the stub, **everything fails** — that's the starting
point TechLead will improve on):

```sh
cd "$TL_HOME"
tl-project.sh set todo path "$APP"
tl-project.sh set todo mode local-only          # fast-forward merge onto main (no remote needed)
tl-project.sh set todo default_branch main
tl-project.sh set todo readiness ready
tl-project.sh set todo test_command "sh test.sh"
tl-project.sh set todo max_files_changed 5
tl-baseline.sh todo                             # records: feat-add, feat-done as known-failing
```

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

## Step 4 — Build the first feature, end to end

### Grill it into a spec

```sh
tl-grill.sh add-list
```

The grill runs its **inference pass**: it answers what it can from your `lead/` files and asks you
only the delta. On a small task, qwen3-coder tends to infer everything (`state=specified`,
0 open) — you'll see the questions and their answer states printed. If it *does* leave one `open`:

```sh
tl-grill.sh show add-list                                   # or: tl-spec.sh qlist tl-add-list
tl-grill.sh answer tl-add-list q2 decided "index is 1-based; store one task per line"
```

### Brief and dispatch

```sh
tl-brief.sh tl-add-list                                     # spec → data/tl-add-list/brief.md

tl-spawn.sh --id add-1 --project "$HOME/todo-app" --project-name todo \
            --kind change --brief "$TL_HOME/data/tl-add-list/brief.md"
```

The worker (opencode) now edits `todo.py` in an **isolated worktree** on branch `tl/add-1`.

### Supervise

```sh
tl-watch.sh --once        # classify the fleet once; or leave `tl-watch.sh` running
tl-peek.sh add-1 20       # watch what the model is doing
tl-state.sh add-1         # authoritative state: working | done | failed
```

On a local model this takes a few minutes. When `tl-state.sh add-1` says `done`, the worker has
committed its edits.

### Gate and deliver

```sh
tl-deliver.sh add-1       # runs tests vs baseline + scope/danger checks, then ff-merges onto main
```

If tests still fail vs baseline, or scope/danger trip, the gate surfaces **findings** and refuses
to merge until you resolve them (approve / skip / fix). A clean feature merges straight onto `main`.
Check it:

```sh
cd "$HOME/todo-app"
TODO_FILE=/tmp/t python3 todo.py add "buy milk" && TODO_FILE=/tmp/t python3 todo.py list
cd "$TL_HOME"
```

---

## Step 5 — Build the second feature

Same loop, now that `add-list` has landed:

```sh
tl-grill.sh  mark-done
tl-brief.sh  tl-mark-done
tl-spawn.sh  --id done-1 --project "$HOME/todo-app" --project-name todo \
             --kind change --brief "$TL_HOME/data/tl-mark-done/brief.md"
tl-watch.sh  --once
tl-deliver.sh done-1
```

Because the baseline already knew `feat-done` was failing, fixing it is **not** a regression — the
gate passes. If `mark-done` had broken `feat-add`, that *would* show as a regression and block the
merge. That's the point of the baseline.

---

## Step 6 — Let the lead say "no"

The most senior move is refusing work. Grill the bait item and reject it:

```sh
tl-grill.sh  rewrite-in-rust
tl-grill.sh  reject tl-rewrite-in-rust "Premature — no perf problem exists; revisit if profiling shows one"
```

The reason is recorded against the backlog (`data/backlog.decisions`), and no worker is ever
spawned. That refusal — not the code — is what makes it a *tech lead* and not an order-taker.

---

## Running a small crew

Independent features can run in parallel. Spawn two, then let the watcher supervise both:

```sh
tl-spawn.sh --id a --project "$HOME/todo-app" --project-name todo --kind change --brief .../brief-a.md
tl-spawn.sh --id b --project "$HOME/todo-app" --project-name todo --kind change --brief .../brief-b.md
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
