# TechLead — Usage (Phase 0)

How to drive what exists today: dispatch a coding agent into an isolated worktree, supervise it
for zero tokens while idle, grill a backlog item into a spec, and deliver a reviewed change.

> **Status:** Phase 0 plumbing. `plan` and `change` kinds. Terminal-only (no Slack). Plain
> `git worktree` (no pool). The judgment layer (`lead/`) is a stub — rules are meant to accrete
> from real grills. Full design: `TechLead — Functional and Technical Analysis.md`; actual scope:
> `TechLead — Grilling Session Decisions.md`.

## Prerequisites

- **bash**, **git** (2.5+), **jq**
- A coding-agent CLI for real workers — currently **Claude Code** (`claude`). Everything also runs
  with the bundled demo workers, which need no agent and spend no tokens.
- macOS or Linux. (Scripts target bash 3.2, macOS's default; BSD `stat`/`date` are used — see
  the `# tl:` ceilings in the scripts for the GNU swaps.)

## Concepts

| Term | Meaning |
|------|---------|
| **owner** | You. Final authority on every merge and published answer. |
| **lead** | The orchestrator. Never writes code. In Phase 0 that's you at the terminal + the scripts. |
| **worker** | One agent, one task, one isolated worktree, on branch `tl/<id>`. |
| **instance** | A checkout of *this* repo. `TL_HOME` points at it. It owns `bin/`, `lead/`, and the gitignored `data/` (durable) and `state/` (volatile). |
| **kind** | `plan` (writes a report, zero blast radius) or `change` (edits code, gated before delivery). |

The pipeline:

```
data/backlog.md → tl-grill → spec.md → tl-brief → brief.md → tl-spawn → worktree
   → worker → tl-watch (supervise) → tl-gate (change only) → tl-deliver → teardown
```

## Setup

`TL_HOME` **is the repo root** — it must contain `bin/` and `AGENTS.md`. Every entry point refuses
to run unless `TL_HOME` is set and valid (a capability guard, not a request).

```sh
cd /path/to/techlead            # this repo
export TL_HOME="$PWD"
export PATH="$PWD/bin:$PATH"     # optional, so you can type `tl-spawn` instead of bin/tl-spawn.sh
```

`data/`, `state/`, and `config/` are created under `TL_HOME` on first use. Override their location
with `TL_DATA` / `TL_STATE` / `TL_WORKTREES` (the tests do this to stay isolated).

## Wire a real agent

Workers and the grill are pluggable adapters, selected by env var:

```sh
export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"   # real Claude Code worker
export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"     # real Claude Code grill inference
```

For a token-free dry run, point them at the demo drivers under `test/` instead
(`test/demo-worker.sh`, `test/demo-grill.sh`).

A worker adapter receives its context via env — `TL_TASK_ID`, `TL_TASK_KIND`, `TL_BRIEF` (a file
path or string), `TL_WORKTREE`, `TL_REPORT` — and must write its deliverable to `$TL_REPORT`.
Swapping in Codex/aider is a new adapter, nothing else.

## Register a project and capture a baseline (needed for `change`)

A `change` task compares test results against a recorded baseline, so a repo needs registering
first. Config is one `key=value` file per project under `data/projects/<name>.conf`, owned by
`tl-project.sh` (never hand-parsed elsewhere).

```sh
tl-project.sh set myapp path /abs/path/to/myapp
tl-project.sh set myapp mode local-only        # local-only (ff-merge) | pr (gh PR)
tl-project.sh set myapp default_branch main
tl-project.sh set myapp readiness ready        # survey | assisted | ready
tl-project.sh set myapp test_command "make test-ids"   # MUST print failing-test ids, one per line
tl-project.sh set myapp max_files_changed 25
tl-project.sh set myapp danger_paths "migrations/** billing/**"

tl-baseline.sh myapp        # runs test_command, records the known-failing set
```

| Key | Meaning |
|-----|---------|
| `path` | Absolute path to the project checkout |
| `mode` | `local-only` → fast-forward merge; `pr` → push + `gh pr create` |
| `default_branch` | Merge target for `local-only` |
| `test_command` | Run in the worktree; **must print failing-test identifiers, one per line** |
| `baseline` / `baseline_at` | Set by `tl-baseline.sh`; the known-failing set and its date |
| `max_files_changed` | Exceeding it is an `ask-user` finding at the gate |
| `danger_paths` | Space-separated globs; touching one is an `ask-user` finding |

> The test-command contract (one failing id per line) is a Phase-0 simplification — wire your test
> runner to emit that. See the `# tl:` note in `tl-gate.sh`.

## The lifecycle, command by command

### 1. Author a backlog item

`data/backlog.md` is a plain markdown queue, one item per heading `## <slug>: <title>`:

```markdown
# Backlog

## add-farewell: Add a farewell function to greet.sh
greet.sh has hello() but no farewell(). Add farewell(name) echoing "goodbye, <name>".
```

### 2. Grill it into a spec

```sh
tl-grill.sh add-farewell
```

The grill runs an **inference pass**: it hands `lead/questions.md` + prior `lead/decisions/` to the
driver, which answers what it can (`source: inferred`) and marks the rest `open` for you. If
everything is inferable, the spec goes straight to `specified`. Otherwise, answer the delta:

```sh
tl-grill.sh answer tl-add-farewell q2 decided "Staging, then prod-eu, then prod-us"
tl-grill.sh show   tl-add-farewell
```

`answer_state` is one of `decided` (a constraint), `leaning` (a default the worker may challenge),
`open` (must be answered before briefing), `spike` (resolve by building).

Refuse an item outright — the most senior move:

```sh
tl-grill.sh reject tl-add-farewell "Premature — revisit next quarter"
```

### 3. Generate the brief

```sh
tl-brief.sh tl-add-farewell     # -> data/tl-add-farewell/brief.md
```

`tl-brief` **refuses** if the spec isn't `specified`, has any `open` question, or has an answer
older than `TL_ANSWER_DECAY_DAYS` (default 30) — a stale answer is worse than none.

### 4. Dispatch a worker

```sh
# plan (zero blast radius)
tl-spawn.sh --id t1 --project /abs/path/to/myapp --kind plan  --brief data/tl-add-farewell/brief.md

# change (edits code, will be gated)
tl-spawn.sh --id t2 --project /abs/path/to/myapp --project-name myapp --kind change \
            --brief data/tl-add-farewell/brief.md
```

`--project-name` links the task to its registry entry (needed for the `change` gate). Spawn
acquires an isolated worktree, creates branch `tl/<id>`, and launches the worker adapter.

### 5. Supervise

```sh
tl-watch.sh            # run forever; wakes you only on actionable events (Ctrl-C to stop)
tl-watch.sh --once     # a single pass (or `tl-watch.sh 10` for 10 passes)
tl-peek.sh t2 20       # last 20 lines of a worker's output
tl-send.sh t2 "use the existing retry helper"   # message a running worker
tl-state.sh t2         # authoritative current state: working|blocked|needs-decision|done|failed
```

The watcher costs **zero tokens while idle** (it polls with `kill -0`/`stat`, not an LLM). When a
worker needs a decision it escalates in the terminal with a stated default; if you don't answer,
the default fires and is logged (park-don't-block).

### 6a. Approve a `plan`

```sh
tl-approve.sh t1        # shows the report; approve / skip / fix (records your decision)
```

### 6b. Gate and deliver a `change`

```sh
tl-gate.sh    t2        # runs tests vs baseline, checks scope + danger → data/t2/findings.json
tl-deliver.sh t2        # self-edit guard + gate, then ff-merge (or open a PR); refuses on open findings
```

Findings are structured and default to `ask-user` (fail-closed). `tl-deliver` will not merge while
any finding is unresolved — the gate is a removed capability, not an instruction.

### 7. Tear down

```sh
tl-teardown.sh t2               # refuses if the worktree is dirty or has undelivered commits
tl-teardown.sh t2 --force       # override the guard
```

The worker's `report.md` in `data/<id>/` survives teardown.

## Ledgers

```sh
tl-cost.sh   report            # per-task token cost by category
tl-metric.sh report            # grill + approval time per feature (the D13 kill-gate inputs)
```

## A full worked example (real agent, ~$0.40 in tokens)

```sh
export TL_HOME="$PWD"
export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"
export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"

# assume myapp is registered and baselined, and backlog.md has ## add-farewell: ...
bin/tl-grill.sh   add-farewell                 # infer → spec (answer any open questions)
bin/tl-brief.sh   tl-add-farewell              # spec → brief
bin/tl-spawn.sh   --id af1 --project /abs/myapp --project-name myapp --kind change \
                  --brief data/tl-add-farewell/brief.md
bin/tl-watch.sh   --once                       # or leave it running
# ... worker edits + commits on tl/af1 ...
TL_APPROVE=yes bin/tl-deliver.sh af1           # gate → ff-merge onto main
```

## Environment variables

| Var | Purpose |
|-----|---------|
| `TL_HOME` | Instance root (= repo root). Required. |
| `TL_DATA` / `TL_STATE` / `TL_WORKTREES` | Override storage locations (default under `TL_HOME`). |
| `TL_WORKER_CMD` | Worker adapter (real agent or demo). |
| `TL_GRILL_CMD` | Grill inference driver. |
| `TL_BACKLOG` | Backlog path (default `data/backlog.md`). |
| `TL_APPROVE=yes` | Non-interactive approval (tests/automation); `TL_RESOLVE` sets the finding resolution. |
| `TL_WATCH_INTERVAL` / `TL_FRESH_SECS` / `TL_DONE_STABLE` | Watcher tuning. |
| `TL_ANSWER_DECAY_DAYS` | Spec-answer staleness threshold (default 30). |

## Known limits (Phase 0)

- **No tmux** → workers run as background processes; `tl-send` is a best-effort mailbox, not
  interactive keystroke injection. Swap `tl-session.sh` for tmux when interactive workers arrive.
- **Plain `git worktree`**, no pool → dependency/build cache isn't preserved between tasks.
- **`TL_HOME` must be the repo root** — a worker's adapter calls `$TL_HOME/bin/*`. A partial
  instance (missing `bin/`) breaks cost/status recording.
- **Single machine, laptop-only** — the crew stops when you sleep; there's no overnight supervision
  or Slack yet.
- Every deliberate shortcut is marked with a `# tl:` comment naming its ceiling and upgrade path.
