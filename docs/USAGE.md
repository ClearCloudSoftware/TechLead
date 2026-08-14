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
| **instance** | A checkout of *this* repo (the tool). `TL_HOME` points at it. It owns `bin/`, `adapters/`, and `AGENTS.md`. |
| **project state** | Each managed repo keeps its own state in `<project>/.techlead/` — `data/` (backlog, specs, registry), `state/` (task status/worktrees), and its own `lead/` (judgment). Gitignored, like `.claude/`/`.superpowers/`. Being *in* the project selects it (nearest `.techlead/` wins). |
| **kind** | `plan` (writes a report, zero blast radius) or `change` (edits code, gated before delivery). |

The pipeline:

```
.techlead/data/backlog.md → tl-grill → spec.md → tl-brief → brief.md → tl-spawn → worktree
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

`TL_HOME` is the **tool** — `config/` is created under it on first use. A managed project's own
`data/`, `state/`, and `lead/` live in `<project>/.techlead/` (created by `tl-onboard`/`tl-new`), and
commands resolve which project by walking up from the current directory to the nearest `.techlead/` —
so **run pipeline commands from inside the project**. Override the resolved paths with
`TL_DATA` / `TL_STATE` / `TL_LEAD` / `TL_WORKTREES` (the tests do this to stay isolated).

### Guided setup (the wizard)

Three commands wrap the raw configuration below, so setup is a few keystrokes instead of a page of
`tl-project` calls — all bash, no new runtime:

```sh
bin/tl-init.sh                       # tool config → config/instance.env: harness, model
bin/tl-onboard.sh /abs/path/to/repo  # brownfield: register an EXISTING repo in place (+ its
                                     #   .techlead/ and a baseline)
bin/tl-new.sh myapp                  # greenfield: create ./myapp (empty) with its own .techlead/
```

**Kickoff a greenfield project (optional).** A brand-new repo is empty, so its domain comes from you.
`tl-kickoff` runs a short **interview right in the terminal** — no Claude Code app:

```sh
cd myapp && bin/tl-kickoff.sh        # asks one question at a time; answer each
```

Each turn is a discrete `claude -p` call; the conversation is kept in a transcript file, so a blank
line pauses it and re-running resumes. When it has enough it drafts `CONTEXT.md` (uncommitted) and
prints ready `tl-backlog add` lines — **review + commit `CONTEXT.md`, and run the backlog lines you
want** (both are yours to approve). `<project>` is inferred from the current `.techlead`. For an
*existing* repo, use `tl-scaffold-context` instead — it derives `CONTEXT.md` + `AGENTS.md` from the code.

`tl-init` writes `config/instance.env`, which every `tl-*` command auto-loads — **env you already
set in the shell still wins** — so you configure the harness/model once instead of every shell.
`tl-onboard` (existing repo, registered at `ready` once baselined) and `tl-new` (new empty repo,
registered at `survey` = plan-only) **call `tl-project`/`tl-baseline` for you; they never write the
registry themselves** (§3.1). All three take `--yes` (plus `TL_ANSWER_*` env) to run
non-interactively. The sections below are the manual equivalents and define every field the wizard
asks about.

## Wire a real agent

Workers and the grill are pluggable adapters, selected by env var:

```sh
export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"   # real Claude Code worker
export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"     # real Claude Code grill inference
```

Or use **[opencode](https://opencode.ai)** — the agent harness is a seam, so this is the only change:

```sh
export TL_WORKER_CMD="$TL_HOME/adapters/opencode-worker.sh"
export TL_GRILL_CMD="$TL_HOME/adapters/opencode-grill.sh"
export TL_OPENCODE_MODEL="ollama/qwen3-coder:30b"   # local, $0; or opencode/*-free, or a cloud model
```

> **For local models, use `ollama/qwen3-coder:30b`.** It's the only coding-specialized tool-caller
> that reliably drives opencode's edit loop, and it's the model validated here end-to-end. Other
> local models either lack tool support (`deepseek-coder-heretic` errors "does not support tools")
> or code weakly / reason instead of acting (gemma, deepseek-r1, the vision models). Any model
> **must** be tools-capable (function calling).
>
> Local models record `$0` cost, and opencode's worker report narrates its tool use (Claude returns
> a cleaner result) — cosmetic; the change, gate, and delivery are identical. Grill *quality* still
> tracks the model: a local model infers coarsely (qwen3-coder tends to mark everything `decided`);
> for sharper grills point `TL_OPENCODE_MODEL` at an `opencode/*-free` or cloud model.

For a token-free dry run with no agent at all, point them at the demo drivers under `test/`
(`test/demo-worker.sh`, `test/demo-grill.sh`).

Four adapters ship today — `claude-{worker,grill}` and `opencode-{worker,grill}` under `adapters/`.
Adding another harness (Codex, aider, …) is just another adapter; nothing in `bin/` changes.

- A **worker** adapter gets `TL_TASK_ID`, `TL_TASK_KIND`, `TL_BRIEF` (file path or string),
  `TL_WORKTREE`, `TL_REPORT`. It does the task in the worktree, writes the deliverable to
  `$TL_REPORT`, and (for `change`) commits on `tl/<id>`.
- A **grill** adapter gets `TL_GRILL_SLUG`, `TL_GRILL_TITLE`, `TL_GRILL_BODY` (file),
  `TL_QUESTIONS` (the bank), `TL_DECISIONS`. It prints one tab-separated
  `qid⇥answer_state⇥source⇥text` line per question and must not touch the instance.

## Register a project and capture a baseline (needed for `change`)

A `change` task compares test results against a recorded baseline, so a repo needs registering
first. Config is one `key=value` file per project under `data/projects/<name>.conf`, owned by
`tl-project.sh` (never hand-parsed elsewhere).

**The easy path is `tl-onboard` above** — it detects the defaults, confirms them, and captures the
baseline for you. What follows is the manual equivalent (and what each field the wizard asks means):

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

**Greenfield with no test runner to detect?** `tl-scaffold-test myapp` drafts a `test.sh` from the
backlog (failing-id-per-line contract) and sets `test_command` for you — then stops. **Review the
draft** (a test defines what "done" means, so it's yours to approve), commit it, and `tl-baseline`.
It never baselines an unreviewed harness and never overwrites an existing `test.sh`. Existing repos
with a known stack don't need it — `tl-onboard`/`tl-detect` already set `test_command`.

**Onboarding docs.** `tl-scaffold-context myapp` drafts `AGENTS.md` (layout, current + deprecated
conventions, danger zones) and `CONTEXT.md` (domain glossary) as real files, then stops. **Review
them — the first `CONTEXT.md` especially is yours to check** — and commit. Once committed, the grill,
review, and answer read them (a worker branches from `HEAD`), so the lead uses your project's
vocabulary instead of guessing. It never overwrites an existing doc.

> **Commit the test harness first.** `test_command` runs in the *worktree*, which a worker branches
> from `HEAD` — so an **uncommitted** harness (or fixtures) is invisible to workers and to the gate,
> and the baseline (run against your working tree) won't match what the gate reruns. `tl-baseline` and
> `tl-spawn` warn when the project tree is dirty; commit before dispatching `change` tasks.

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

`.techlead/data/backlog.md` (in the project) is a plain markdown queue, one item per heading
`## <slug>: <title>`:

```markdown
# Backlog

## add-farewell: Add a farewell function to greet.sh
greet.sh has hello() but no farewell(). Add farewell(name) echoing "goodbye, <name>".
```

Edit the file directly, or use the helper (it validates the slug and refuses duplicates):

```sh
tl-backlog.sh add add-farewell "Add a farewell function to greet.sh" \
  'greet.sh has hello() but no farewell(). Add farewell(name) echoing "goodbye, <name>".'
tl-backlog.sh list      # show the queue
```

The `<slug>` must be bare/lowercase (`a-z0-9-`) — it becomes the task id `tl-<slug>` and branch `tl/tl-<slug>`.

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

**Propose-mode (fresh project, empty bank).** The grill applies *your* `lead/questions.md`; on a new
project that bank is empty, so the grill has nothing to ask and `tl-run` refuses to dispatch (fail
closed, #49). To bootstrap the bank, let the lead *propose* candidate questions for you to curate:

```sh
tl-grill.sh propose add-farewell     # -> data/proposals/question-add-farewell.md (candidates, NOT in lead/)
# open the file, delete the ones you don't want, then:
tl-grill.sh promote add-farewell     # appends the survivors to lead/questions.md (provisional, hits:0)
tl-run.sh add-farewell               # re-grills against the now-seeded bank
```

The LLM only ever *proposes*; nothing enters `lead/` without your `promote`. Promoted questions land
provisional (`_scar:_ (proposed — unproven)`, `hits: 0`) — the reuse counter earns or prunes them
(D4). When `TL_GRILL_PROPOSE_CMD` is configured (tl-init wires it for the claude harness), `tl-run`
auto-drafts the candidates for you at the empty-bank stop; otherwise run `tl-grill propose` yourself.

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

Since the spec and registration already know these, **`tl-spawn <id>` resolves them for you** —
brief from `data/<id>/brief.md`, project/name from the spec's `project` field or the sole registered
project, and kind from the project's readiness (`survey`→plan, else `change`):

```sh
tl-spawn.sh tl-add-farewell        # same dispatch, resolved from existing state
```

Explicit flags always override (the manual path), and if a required value can't be resolved it
refuses naming the missing piece — it never guesses a default that would dispatch the wrong thing.

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

**A live queue view (convenience).** `tl-top` is a read-only `curses` dashboard, refreshing on a
timer (`TL_TOP_INTERVAL`, default 2s) and on keypress. It shows the whole owner queue, not just
running workers — it joins three sources, so an item you added to the backlog and never grilled,
or grilled and left with open questions, is visible too:

| Source | Contributes |
|---|---|
| `data/backlog.md` | items with no task yet (`never grilled`) |
| `data/<id>/spec.md` | one row per **open grill question** |
| `state/<id>.meta` + `tl-state` + `findings.json` | gate findings, worker decisions, blocked/failed, ready-to-review |

```sh
tl-top                 # live read-only queue view; q to quit
```

**Three views over one cursor** — `1`/`2`/`3`, or `tab` to cycle. The cursor is `(task, qid)` and
is shared, so switching view re-frames the same decision rather than losing your place:

| View | Shows |
|---|---|
| `1` inbox | one row per thing waiting on you, loudest first; working tasks collapse to one quiet line |
| `2` briefing | that one decision full-screen — the question, what's already decided on the item, what the backlog asked for |
| `3` modal | `:backlog` · `:q <slug>` · `:fleet` · `:findings <id>` · `:bank` — and the only place answered questions appear, so it's where you correct one the grill inferred |

Every task runs in **its own worktree on its own branch** (`tl-spawn`, §3.11), so parallel workers are
the normal case rather than an edge one. A dispatched row names both: `:fleet` carries a `BRANCH`
column, and the detail pane adds the worktree path (relative to the project), the base sha, how many
commits ahead it is, and whether it has uncommitted work — the state `g` is about to merge. Those
last two need `git`, so they are computed for the selected row only, never for the whole fleet on the
refresh timer.

The keymap is global (the same keys work in all three views) — navigation is instant, consequences
are deliberate:

| Key | Action | How |
|-----|--------|-----|
| `1` `2` `3` / `tab` | switch view | in-TUI, instant |
| `↑` / `↓` (or `k` / `j`) | move the cursor | in-TUI, instant |
| `d` / `l` / `s` | answer the selected question `decided` / `leaning` / `spike` | prompt, then `tl-grill answer <id> <qid> <state> "<text>"` |
| `x` | reject the item (terminal, D10) | prompt for a reason, then `tl-grill reject` |
| `e` | edit the backlog item, or the spec | `$EDITOR` (at the item's line), full-screen |
| `n` | jump to the next waiting item | in-TUI, instant |
| `p` | peek the selected worker's output full-screen | opens it in `$PAGER` (default `less`); returns on exit |
| `r` | run / resume the pipeline for the selected item | **confirm**, then `tl-run <slug>` in the normal terminal |
| `g` | resolve the delivery gate for the selected task | **confirm**, then `tl-deliver <id>` — its gate prompts approve/skip/fix per finding |
| `/` `:` | filter · command (view 3) | prompt |
| `?` / `q` | keys · quit | — |

The answer prompt is `curses.textpad` (`^A`/`^E`/`^K`/`^U`, arrows, wrapping). It opens **seeded**:
an already-answered question starts with its answer, so accepting what the grill inferred is `d`
then `enter`, and correcting it is the same two keys with typing in between. An *open* question
starts empty — `spec.md`'s 5th field still holds the question at that point, not an answer.

It **renders, never mutates.** Every key with a consequence runs the real `tl-*` command, so their
validation and refusals still apply — `d`/`l`/`s`/`x` go through `tl-grill` (which is what logs the
correction to `inferred-outcomes.tsv`), `e` hands the file to `$EDITOR`, `r`/`g` each require a
confirm and then drop you into that command's own approve/skip/fix prompts. There is no
bulk-approve and no single-keystroke merge. It is **never load-bearing**: if `tl-top` is broken or
absent, every command above is the fallback, and killing it — even mid-prompt — changes nothing
(the shelled command ran or didn't, on its own terms; `tl-top` holds no state).

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

## Drive the pipeline in one command: `tl-run`

`tl-run <backlog-slug>` walks a single item through the lifecycle above — grill → brief → spawn →
gate/deliver — by calling the same `tl-*` commands, and **stops at exactly the two points where your
judgment decides the outcome**:

1. **Spec approval / reject** — after the grill, if any question is `open` (or the lead rejected the
   item) it halts and shows the delta; it never auto-answers, and never dispatches an unspecified
   spec. A clean, zero-open spec advances automatically (it prints the spec path and the
   inferred/answered counts so you can still inspect it).
2. **Gate findings** — at delivery, if any `ask-user` finding is unresolved it halts with the
   findings and the three resolutions (approve / skip / fix). It never auto-resolves.

Everything between and after those is deterministic. It does **not** babysit the worker: after
spawning it hands supervision to `tl-watch` and returns, so a minutes-long worker never holds your
terminal. Re-run `tl-run <slug>` once the worker is `done` to hit the gate.

```sh
tl-run.sh add-farewell         # grill → (stop, or auto-advance) → brief → spawn, then returns
# ... tl-watch wakes you when the task is ready ...
tl-run.sh add-farewell         # resumes at the gate → deliver
```

It holds **no state of its own**: the current stage is recomputed every run from the spec, brief,
task meta, `tl-state`, and findings. So it is killable and resumable — re-running it, or dropping
back to the individual `tl-*` commands above, always continues from where the pipeline actually is.
`tl-run` is a thin convenience over those commands, **not** a replacement; the manual path stays the
fallback when you want finer control.

> **Multi-project instances.** `tl-run` takes only a slug, so it leans on `tl-spawn`'s resolution to
> pick the project — the sole registered one, or the spec's `project` field. If you manage more than
> one project, pin it first with `tl-spec.sh set tl-<slug> project <name>` (otherwise the spawn stage
> refuses, naming the missing piece), or dispatch that one by hand with
> `tl-spawn.sh tl-<slug> --project <path> --project-name <name>`.

## Ledgers

```sh
tl-cost.sh   report            # per-task token cost by category
tl-metric.sh report            # grill + approval time per feature (the D13 kill-gate inputs)
tl-metric.sh outcome           # per-grill inferred-answer accept/correct — the risk-1 signal (§8.1)
```

The **outcome** view is the cheapest test of the core bet — "does `lead/` capture me?" (Epic 6/E6.4).
Every inferred answer the owner leaves standing is an **accept**; overriding one with
`tl-grill.sh answer <id> <qid> …` logs a **correct**. When a shipped feature reverts or gets
hotfixed, record the lite outcome note by hand (E6.5/D11), citing the `q#` that missed it:

```sh
tl-spec.sh set <id> outcome "q3 missed the auth edge case — reverted"
```

The judgment layer's required shape (the ladder, non-application list, intensity, persistence, and
the per-rule `hits:` counter) lives in **`lead/SHAPE.md`**. Content accretes from real grills — never
seed it from someone else's judgment.

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
| `TL_HOME` | Tool root (= this repo's root). Required. |
| `TL_DATA` / `TL_STATE` / `TL_LEAD` / `TL_WORKTREES` | Override storage locations (default: the nearest `<project>/.techlead/`, else `TL_HOME`). |
| `TL_WORKER_CMD` | Worker adapter (real agent or demo). |
| `TL_GRILL_CMD` | Grill inference driver. |
| `TL_OPENCODE_MODEL` | Model for the opencode adapters; must support tools. **Local pick: `ollama/qwen3-coder:30b`.** |
| `TL_BACKLOG` | Backlog path (default `<project>/.techlead/data/backlog.md`). |
| `TL_APPROVE=yes` | Non-interactive approval (tests/automation); `TL_RESOLVE` sets the finding resolution. |
| `TL_WATCH_INTERVAL` / `TL_FRESH_SECS` / `TL_DONE_STABLE` | Watcher tuning. |
| `TL_TOP_INTERVAL` | `tl-top` refresh interval, in seconds (default 2). |
| `PAGER` | Pager for `tl-top`'s `p` (peek) key (default `less`). |
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
