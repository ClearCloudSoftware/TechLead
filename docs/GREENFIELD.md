# TechLead — Greenfield walkthrough

Zero to one shipped feature on a brand-new repo, in seven commands. Then everything underneath
them, so you can drop to finer grain whenever the fast path isn't what you want.

The spine builds a real (tiny) thing: **`habit`**, a shell CLI that tracks habits in a text file.
Substitute your own app — the shape doesn't change.

> Companion docs: [USAGE.md](USAGE.md) is the reference for each command in isolation. This one is
> the *order*, and why each step exists. Terminology (owner / lead / worker / kind) is defined there.

---

## The seven commands

Everything below is elaboration on this:

```sh
tl-init.sh                                        # 1. once per machine
tl-new.sh habit && cd habit                       # 2. create + register the project
#    …write test.sh, commit it…                   # 3. define "correct" (the only writing you do)
tl-project.sh set habit test_command "sh test.sh"
tl-baseline.sh habit                              # 4. survey → ready
#    …append a backlog item…                      # 5.
tl-run.sh add-habit                               # 6. → STOPS: curate the question bank
tl-grill.sh promote add-habit                     #    (owner-only decision)
tl-run.sh add-habit                               # 7. grill → brief → spawn
tl-watch.sh                                       #    zero-token supervision
tl-run.sh add-habit                               #    resume → gate → merged
```

Three of those are **stops**, not steps: TechLead deliberately hands you the question bank, the
open grill questions, and the gate findings. Those are the product. Everything else is transport.

---

## Step 1 — configure the tool (once per machine)

`TL_HOME` is the **tool** checkout, not your project. Every `tl-*` command refuses to run without it
— a capability guard, not a request.

```sh
cd ~/projects/personal/techlead/techlead
export TL_HOME="$PWD"
export PATH="$TL_HOME/bin:$PATH"

tl-init.sh
```

It asks one question (harness: `claude` or `opencode`) and writes `config/instance.env`:

```sh
export TL_WORKER_CMD="${TL_WORKER_CMD:-$TL_HOME/adapters/claude-worker.sh}"
export TL_GRILL_CMD="${TL_GRILL_CMD:-$TL_HOME/adapters/claude-grill.sh}"
export TL_GRILL_PROPOSE_CMD="${TL_GRILL_PROPOSE_CMD:-$TL_HOME/adapters/claude-grill-propose.sh}"
export TL_SCAFFOLD_TEST_CMD="${TL_SCAFFOLD_TEST_CMD:-$TL_HOME/adapters/claude-scaffold-test.sh}"
export TL_SPECDIFF_CMD="${TL_SPECDIFF_CMD:-$TL_HOME/adapters/claude-specdiff.sh}"
export TL_STANDARDS_CMD="${TL_STANDARDS_CMD:-$TL_HOME/adapters/claude-standards.sh}"
export TL_ANSWER_CMD="${TL_ANSWER_CMD:-$TL_HOME/adapters/claude-answer.sh}"
```

Conditional assignments — anything already exported in your shell **wins over the file**. Every
`tl-*` command auto-loads it, so you configure the harness once instead of per shell.

Put the two `export`s in your `~/.zshrc`. They are not persisted by `tl-init`.

<details>
<summary><b>Finer grain</b> — what each adapter turns on, and the token-free dry run</summary>

`tl-init` is pure convenience; the manual equivalent is exporting the vars yourself. Useful when you
want a dry run with no agent and no tokens at all:

```sh
export TL_WORKER_CMD="$TL_HOME/test/demo-worker.sh"
export TL_GRILL_CMD="$TL_HOME/test/demo-grill.sh"
```

What each one turns on — every adapter fails closed with a named error rather than degrading
silently, so an unset one costs you the feature, never correctness:

| Var | Enables |
|---|---|
| `TL_WORKER_CMD` | the coding worker itself |
| `TL_GRILL_CMD` | the grill's inference pass over your question bank |
| `TL_GRILL_PROPOSE_CMD` | auto-drafting candidate questions at the empty-bank stop (Step 5) |
| `TL_SCAFFOLD_TEST_CMD` | `tl-scaffold-test` drafting a `test.sh` from your backlog (Step 3) |
| `TL_SPECDIFF_CMD` | the Spec axis — *did the change do what the spec decided?* Folds into **every change gate**, and into `tl-review` |
| `TL_STANDARDS_CMD` | the Standards axis (advisory craft review), `tl-review` only |
| `TL_ANSWER_CMD` | the `answer` kind (`tl-answer "why did we…"`) |

`TL_SPECDIFF_CMD` is the load-bearing one. `tl-gate` calls the Spec axis with `|| true`, so an unset
judge **silently skips it** — the gate would check tests, scope, and paths but never the spec's
`decided` answers, which is the part that makes it more than a `git merge`.

**Using opencode instead?** `tl-init` writes the two opencode adapters and prompts for
`TL_OPENCODE_MODEL` (must support tool-calling; `ollama/qwen3-coder:30b` is the validated local
pick). The other five have no opencode adapter yet, so they stay unset: Step 3 means writing
`test.sh` by hand, Step 5 means seeding `lead/questions.md` by hand, and the gate runs without the
Spec axis.
</details>

---

## Step 2 — create the project

```sh
cd ~/projects           # tl-new creates ./<name> right here, like `git init`
tl-new.sh habit
cd habit
```

What you get:

```
habit/
├── .git/                       # initialized, branch main, one empty commit
├── .gitignore                  # contains `.techlead/`
└── .techlead/                  # private working state — NOT source
    ├── data/                   # backlog, specs, briefs, reports, registry, ledgers
    │   └── projects/habit.conf
    ├── state/                  # task meta, event logs, worktrees
    └── lead/                   # ← the judgment layer. Yours. Starts as stubs.
        ├── questions.md        #   the grill question bank (empty by design)
        ├── principles.md
        ├── review-rubric.md
        └── decisions/
```

**Being *in* the directory is what selects the project.** Every command walks up from `$PWD` to the
nearest `.techlead/`. There is no `--project` flag to remember and no ambiguity when you manage
several repos — just `cd`.

The registry entry `tl-new` wrote for you:

```
path=/Users/you/projects/habit
mode=local-only          # ff-merge into main; no remote yet
default_branch=main
max_files_changed=25
readiness=survey         # ← no tests exist, so: plan tasks only
```

`readiness=survey` is the important one. A repo with no tests has no completion criterion, so
TechLead refuses to let a worker *change* it. Step 4 lifts that.

<details>
<summary><b>Finer grain</b> — the manual registration, and the brownfield path</summary>

`tl-new` writes nothing itself; it calls `tl-project`, which is the single owner of the registry.
The equivalent by hand:

```sh
tl-project.sh set habit path /abs/path/to/habit
tl-project.sh set habit mode local-only          # local-only (ff-merge) | pr (push + gh pr create)
tl-project.sh set habit default_branch main
tl-project.sh set habit readiness survey         # survey | assisted | ready
tl-project.sh set habit max_files_changed 25     # exceeding it → ask-user finding at the gate
tl-project.sh set habit danger_paths "migrations/** billing/**"   # touching one → ask-user finding
tl-project.sh get habit readiness                # read any key back
```

`danger_paths` is empty on a new project. Fill it the moment there's something scary — it's the
cheapest guardrail in the system.

**Existing repo instead?** `tl-onboard.sh /abs/path/to/repo` — registers it in place (it never
moves), proposes detected defaults for each field, confirms them with you, and captures a baseline.
The detection is `tl-detect.sh mode|branch|test-command|danger-paths <path>`, which you can run
standalone; it prints nothing when it can't tell, so the wizard asks plainly rather than guessing.

Both wizards take `--yes` (plus `TL_ANSWER_<KEY>` env) for non-interactive runs.

To create every project under a fixed directory instead of `$PWD`, export `TL_PROJECTS_DIR`.
</details>

---

## Step 3 — write `test.sh` (the one thing only you can do)

This is the contract that makes everything else mechanical:

> **`test_command` prints one failing-test identifier per line. Silence means green.**

That's it. No framework, no exit-code convention. The gate does set arithmetic on those lines
against a recorded baseline, so anything that can `echo` an id works.

Write it *before* the app exists — the ids describe behaviours you want, all of them currently
broken:

```sh
cat > test.sh <<'EOF'
#!/bin/sh
# test.sh — prints one id per FAILING behaviour; silence means green.
fail() { echo "$1"; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
HABITS="$work/habits.txt"; export HABITS

./habit add read 2>/dev/null
grep -qx 'read' "$HABITS" 2>/dev/null || fail add-appends

./habit add write 2>/dev/null
[ "$(./habit list 2>/dev/null | wc -l | tr -d ' ')" = "2" ] || fail list-shows-all

./habit add 2>&1 >/dev/null | grep -q usage || fail add-requires-name

exit 0        # the ids on stdout are the result; the exit code is ignored
EOF
chmod +x test.sh
```

Note the third check asserts on the *message*, not on the exit code. `./habit add` exiting non-zero
is also what "command not found" looks like, so an exit-code check would report that behaviour as
**passing** while the app doesn't exist yet — a false green, precisely when you can least afford one.
Assert on something only the real implementation can produce.

**Commit it. This matters more than it looks.**

```sh
git add test.sh .gitignore && git commit -m "test: behaviour harness for habit"
```

A worker gets an isolated worktree branched from `HEAD`. An uncommitted harness is **invisible** to
it *and* to the gate — and your baseline, captured against the working tree, would then measure
something neither ever sees. `tl-baseline` and `tl-spawn` both warn on a dirty tree for exactly this
reason. Take the warning seriously.

<details>
<summary><b>Finer grain</b> — let TechLead draft the harness (<code>tl-scaffold-test</code>)</summary>

If you'd rather not start from a blank file, `tl-scaffold-test` drafts one *from your backlog*. That
means writing the backlog item first — so you'd do Step 5's `cat >>` before this, then:

```sh
tl-scaffold-test.sh habit
```

```
tl: drafted /Users/you/projects/habit/test.sh  and set test_command='sh test.sh'.
tl: REVIEW it — a test defines what 'done' means, which is yours to approve. Then, in order:
      $EDITOR test.sh
      git add test.sh && git commit -m 'add test harness'
      tl-baseline habit
```

It writes `test.sh`, sets `test_command`, and **stops**. It never baselines for you and never
overwrites an existing `test.sh` — what "done" means is the one thing it won't decide.

Read every line before committing. A harness you didn't read is a definition of "correct" you didn't
choose, and every gate from here on is measured against it. This is the same trap as rubber-stamping
the question bank in Step 5, one layer down.

Existing repo with a real test runner? You don't need this — `tl-detect` / `tl-onboard` already set
`test_command` from the stack they found.
</details>

---

## Step 4 — baseline, and the promotion to `ready`

```sh
tl-project.sh set habit test_command "sh test.sh"
tl-baseline.sh habit
```

```
tl: capturing baseline for habit  (sh test.sh)
tl: baseline recorded — 3 known-failing test(s)
tl: habit promoted survey → ready (change tasks now allowed)
```

Three failing is correct — `./habit` doesn't exist yet. The baseline is **not** "green"; it's
"here is what is known-broken today." The gate flags only tests that are failing *now* and were
*not* failing at baseline. That's what makes TechLead usable on a real, imperfect repo instead of
demanding a clean slate.

Re-run `tl-baseline` whenever you deliberately accept a new failure. Re-baselining an
already-`ready` project leaves its readiness alone.

<details>
<summary><b>Finer grain</b> — the readiness ladder</summary>

| readiness | Means | Default kind for `tl-spawn` |
|---|---|---|
| `survey` | no tests, no completion criterion | `plan` — writes a report, zero blast radius |
| `assisted` | tests exist, you want a human in the loop | `change` |
| `ready` | tests + baseline | `change` — edits code, gated before delivery |

You can pin kind per task regardless: `tl-spec.sh set tl-add-habit kind plan`.

**The plan-first alternative.** If you'd rather not hand-write `test.sh`, leave the project at
`survey` and dispatch a `plan` task ("propose a structure and a test harness for a habit CLI").
You get `report.md` to read and approve with `tl-approve.sh` — no code is touched. Then you write
the harness from its proposal and baseline as above. Slower, and it costs tokens for something you
can usually type faster than you can review. The direct path above is the recommended one.
</details>

---

## Step 5 — the first feature, and the empty question bank

The backlog is plain markdown, one item per `## <slug>: <title>` heading:

```sh
cat >> .techlead/data/backlog.md <<'EOF'

## add-habit: Add a habit to the list
`habit add <name>` appends <name> to $HABITS (default ./habits.txt), one per line, prints nothing.
`habit list` prints the file. Missing <name> → usage message on stderr, non-zero exit.
EOF

tl-run.sh add-habit
```

And it stops:

```
tl-run: STOP — no questions in the bank for 'add-habit'; I drafted candidates for you to curate.
  candidates: .techlead/data/proposals/question-add-habit.md
  next: prune the ones you don't want, then:  tl-grill promote add-habit  →  tl-run add-habit
```

**This stop is the product, not an error.** The grill applies *your* question bank — the questions
that come from things that have actually bitten you. A fresh project has none, so the grill has
nothing to ask, so TechLead refuses to dispatch un-grilled work. Fail closed.

Because the `claude` harness is configured, it drafted candidates for you. Open the file, and
**delete every question you don't want asked of every future feature forever.** Pruning is the whole
exercise — a bank that asks everything is a bank that asks nothing.

```sh
$EDITOR .techlead/data/proposals/question-add-habit.md
tl-grill.sh promote add-habit
```

```
tl: promoted 4 question(s) into questions.md (provisional, hits:0) — archived …promoted
tl: now re-grill against the seeded bank:  tl-run add-habit
```

Survivors land in `.techlead/lead/questions.md` as provisional:

```markdown
### What happens to existing data when this changes shape?
hits: 0   last: —
_scar:_ (proposed — unproven)
```

The LLM only ever *proposes*. Nothing enters `lead/` without your `promote` — it is the one
owner-only directory in the system. The `hits:` counter earns or prunes each question over time;
write a real `_scar:_` line when one first catches something, and delete any that never fire.

<details>
<summary><b>Finer grain</b> — proposals, and the two feedback loops that fill the bank</summary>

```sh
tl-grill.sh propose add-habit     # draft candidates without going through tl-run
tl-grill.sh promote add-habit     # append survivors to lead/questions.md, archive the proposal
```

`tl-propose.sh rule|question <key> <case-file>` is the shared propose-not-write machinery: candidates
always land in `data/proposals/`, never in `lead/`. Idempotent per key, so re-runs don't re-spend.

Two loops feed the bank from real use, both draft-only:

- **`tl-override-loop.sh`** — every time you correct an inferred grill answer, that correction is
  logged to `data/inferred-outcomes.tsv` and becomes a candidate `lead/principles.md` rule: the rule
  that would have made the lead agree with you in the first place.
- **`tl-escalation-loop.sh`** — every question a worker had to ask mid-flight is a question the grill
  should have asked at spec time. Each resolved escalation becomes a candidate question. *(Dormant
  until the worker adapter emits escalations.)*

`bin/tl-scrub.sh PATH...` scans for secrets before content enters `lead/` or `decisions/`. It never
strips — on a hit it fails closed and names the offender, so the write escalates to you.

The required shape of every `lead/` file — the ladder, the non-application list, the `hits:` counter,
the ~200-line consolidation ceiling — is in `lead/SHAPE.md`. **Never seed `lead/` from someone else's
judgment**, including mine.
</details>

---

## Step 6 — grill, brief, spawn

```sh
tl-run.sh add-habit
```

The grill runs an inference pass: your questions + prior decisions go to the driver, which answers
what it can from the record (`source: inferred`) and marks the rest `open`.

**If anything is open, it stops** — and never auto-answers:

```
tl-run: STOP — spec 'tl-add-habit' is 'drafted' with 1 open question(s); not dispatching.
  open [q3] Where does the data live, and what happens when it's missing?
  answer:  tl-grill answer tl-add-habit <qid> <decided|leaning|spike> [text]
```

```sh
tl-grill.sh answer tl-add-habit q3 decided "\$HABITS, default ./habits.txt; create on first write"
tl-run.sh add-habit
```

| `answer_state` | Means |
|---|---|
| `decided` | a constraint — the worker must honour it (and only these can be *violated* at the spec-diff) |
| `leaning` | a default the worker may challenge |
| `open` | must be answered before briefing — blocks |
| `spike` | resolve by building |

Zero open questions and it advances on its own:

```
tl-run: spec 'tl-add-habit' specified — 3 inferred, 1 owner-answered, 0 open
tl: run[tl-add-habit]: brief
tl: spawn tl-add-habit — kind=change, project=habit
tl-run: dispatched 'tl-add-habit' and left it supervised — do NOT babysit the worker.
```

`tl-run` **returns immediately**. It never holds your terminal for a minutes-long worker.

Note the task id: `tl-` + the slug → **`tl-add-habit`**. Every per-task command below takes that.

<details>
<summary><b>Finer grain</b> — each stage on its own</summary>

```sh
tl-grill.sh add-habit                        # grill only
tl-grill.sh show tl-add-habit                # print the spec
tl-grill.sh reject tl-add-habit "Premature"  # refuse the item outright — the most senior move
tl-spec.sh qlist tl-add-habit                # qid|state|source|answered_at|text
tl-spec.sh open-count tl-add-habit
tl-spec.sh get tl-add-habit state
tl-spec.sh set tl-add-habit project habit    # pin the project on a multi-project instance
tl-brief.sh tl-add-habit                     # spec → brief
tl-spawn.sh tl-add-habit                     # resolves project/kind/brief from state
```

`spec.md` is **durable** (what and why — it becomes the ADR). `brief.md` is **disposable** (how).
Don't collapse them.

`tl-brief` *refuses* an unspecified spec, one with any open question, or one whose answers are older
than `TL_ANSWER_DECAY_DAYS` (default 30) — a stale answer is worse than none. That refusal is the
point of the step, and it's a script guard, not a prompt instruction.

The full-flag spawn, when you want to override resolution:

```sh
tl-spawn.sh --id af1 --project /abs/path/habit --project-name habit --kind change \
            --brief .techlead/data/tl-add-habit/brief.md
```
</details>

---

## Step 7 — supervise

```sh
tl-watch.sh          # runs until Ctrl-C; wakes you only on actionable events
```

**Zero tokens while idle.** It polls with `kill -0` and `stat`, not an LLM. There is no LLM anywhere
in the supervision loop.

```sh
tl-watch.sh --once            # single pass
tl-watch.sh 10                # ten passes
tl-state.sh tl-add-habit      # authoritative: working|blocked|needs-decision|done|failed
tl-peek.sh  tl-add-habit 40   # last 40 lines of the worker's output
tl-send.sh  tl-add-habit "use the existing arg parser"
tl-top                        # live fleet dashboard; q to quit
```

`tl-state` is the **only** correct way to read current state. `state/<id>.status` is an append-only
event log — its tail is the last *event*, not the current state. A worker that resumed after an
escalation leaves the tail reading `needs-decision` forever; `tl-state` reconciles it against process
liveness and worktree mtime and correctly reports `working`.

`tl-top` sorts stop-condition tasks (needs-decision, unresolved findings, blocked, failed) loud to
the top, so a glance answers "who needs me". It renders and never mutates: `p` peeks, `r` runs
`tl-run`, `g` runs `tl-deliver` — each behind a confirm, each dropping you into that command's own
prompts. No bulk-approve, no single-keystroke merge. It is never load-bearing; killing it mid-action
changes nothing.

When a worker needs a decision it escalates in the terminal **with a stated default**. If you don't
answer, the default fires and is logged — park, don't block. Owner silence is safe, never a deadlock.

---

## Step 8 — gate and deliver

Once `tl-state` says `done`:

```sh
tl-run.sh add-habit
```

This runs the self-edit guard, then the gate:

```
tl: gate for tl-add-habit — 2 file(s) changed, 1 finding(s)
  habit     | 34 ++++++++++
  README.md |  8 ++++
  [f1] scope-cap-exceeded: 2 files changed > max 1
resolve [f1] approve/skip/fix? [approve]
```

The gate produces **structured findings, not a pass/fail bit** (`data/tl-add-habit/findings.json`).
It checks four things:

| Rule | Fires when |
|---|---|
| `test-regression` | a test fails now that wasn't failing at baseline |
| `scope-cap-exceeded` | more files changed than `max_files_changed` |
| `danger-path` | the change touched a `danger_paths` glob |
| `tl-shortcut-danger` / `-malformed` | a `# tl:` shortcut on a danger path, or one naming no upgrade path |

Plus `spec-*` findings when `TL_SPECDIFF_CMD` is set — the Spec axis, checking the diff against the
spec's `decided` answers.

Every finding routes through `lead/review-rubric.md`. **v1's rubric has an empty auto-fix set, so
everything classifies `ask-user` and blocks** — deliberately. The `class_source` field records
`default:no-entry` so that emptiness stays legible rather than reading as a rubber stamp.

Resolve each `approve` / `skip` / `fix`, and a clean gate delivers:

```
tl: delivered tl-add-habit — fast-forward merged tl/tl-add-habit into main
```

The gate is **removed capability, not instruction** — `tl-deliver` will not merge while any finding
is unresolved or marked `fix`. With no tty and no `TL_APPROVE`, it leaves findings unresolved and
blocks rather than defaulting to approve.

```sh
tl-teardown.sh tl-add-habit     # release the worktree; report.md survives
```

Teardown refuses on a dirty worktree, or on commits that never left it — it keys on the `delivered`
marker `tl-deliver` records for both paths (`ff-merge:<branch>` and `pr:<url>`), so a merged branch
tears down cleanly and genuinely undelivered work doesn't. `--force` overrides both guards.

<details>
<summary><b>Finer grain</b> — the gate stages, and the standalone review kind</summary>

```sh
tl-gate.sh    tl-add-habit    # gate only; writes findings.json
tl-deliver.sh tl-add-habit    # self-edit guard + gate + merge/PR
tl-approve.sh tl-add-habit    # for plan tasks: show the report, record approve/skip/fix
tl-classify.sh test-regression        # which class does this rule map to, and why
tl-shortcut.sh tl-add-habit           # the `# tl:` annotated-shortcut detector, standalone
tl-guard-selfedit.sh /abs/path/habit  # refuse if the primary checkout sits on a tl/* branch

TL_APPROVE=yes TL_RESOLVE=approve tl-deliver.sh tl-add-habit   # non-interactive (CI/tests)
```

**The `review` kind** — a standalone draft review of an already-built change, two axes run as
parallel sub-agents so nits never drown intent:

```sh
tl-review.sh tl-add-habit          # → data/<id>/review-draft.md
```

- **Spec axis** (`tl-specdiff.sh`) — per `decided` question: satisfied / violated / couldn't-evaluate,
  each verdict showing its work. Only `decided` can be violated. "Couldn't-evaluate" is as loud as a
  violation — no silent pass. Also runs *blocking* at the change gate whenever configured.
- **Standards axis** (`tl-standards.sh`) — borrowed craft review against `AGENTS.md` +
  `lead/review-rubric.md`. Advisory, never blocking, `review` kind only.

`tl-review` is **draft-only**: nothing is posted, merged, or resolved. You dispose.

**The `answer` kind** — ask your own written record a question, with a citation per claim:

```sh
tl-answer.sh "why did we put habits in a flat file instead of sqlite?"
tl-answer.sh "what did we decide about storage?" ./CONTEXT.md    # widen the corpus
```

Corpus: this project's `lead/decisions/` + its grill specs + `lead/principles.md`, plus an optional
context file. Not briefs, not the backlog — those are throwaway or not-yet-decisions. It answers
"I don't know — no basis in your notes" rather than manufacturing a guess, and flags superseded ADRs
instead of quoting them as live.
</details>

---

## The loop, from here on

Every feature after the first is three commands:

```sh
#   append `## <slug>: <title>` + a sentence to .techlead/data/backlog.md
tl-run.sh <slug>       # grill  → (answer any open questions) → brief → spawn
tl-watch.sh            # zero-token supervision
tl-run.sh <slug>       # gate   → (resolve any findings) → merged
```

`tl-run` holds **no state of its own** — it recomputes the stage every invocation from the spec,
brief, task meta, `tl-state`, and findings. So it is killable and resumable: re-run it, or drop to
the individual commands, and it always continues from where the pipeline actually is. It is a thin
convenience over those commands, never a replacement.

As the bank fills, more questions come back `inferred` and fewer stop you. That curve *is* the
product. Measure it:

```sh
tl-metric.sh outcome     # per-grill inferred-answer accept vs correct — "does lead/ capture me?"
tl-metric.sh report      # grill + approval time per feature
tl-cost.sh   report      # token cost per task, by category
```

Every inferred answer you leave standing is an **accept**; every one you override with `tl-grill
answer` logs a **correct**. When a shipped feature reverts or gets hotfixed, record it by hand
against the question that missed:

```sh
tl-spec.sh set tl-add-habit outcome "q3 missed the empty-file case — reverted"
```

---

## Command index

All 41 scripts in `bin/`. Bold entries are the greenfield path.

**Setup and registration**

| | |
|---|---|
| **`tl-init`** | instance config wizard → `config/instance.env` (harness, model, adapters) |
| **`tl-new`** | greenfield: create + register an empty repo at `readiness=survey` |
| `tl-onboard` | brownfield: register an existing repo in place, detect defaults, baseline it |
| **`tl-project`** | single owner of the registry — `get`/`set`/`path` per key |
| **`tl-baseline`** | capture the known-failing set; promotes `survey` → `ready` |
| `tl-scaffold-test` | greenfield only: draft `test.sh` from the backlog, set `test_command`, then stop |
| `tl-detect` | suggest one default (mode/branch/test-command/danger-paths) or stay silent |
| `tl-wizard` | *(sourced)* prompt helpers; `TL_YES` / `TL_ANSWER_<KEY>` make wizards scriptable |

**Pipeline driver**

| | |
|---|---|
| **`tl-run`** | walk one backlog item through the whole lifecycle; stops only at your two decisions |

**Grill and spec**

| | |
|---|---|
| **`tl-grill`** | grill a slug · `answer` · `reject` · `show` · `propose` · **`promote`** |
| `tl-spec` | single owner of `spec.md` — `init`/`get`/`set`/`qset`/`qlist`/`open-count`/`path` |
| `tl-brief` | spec → brief; refuses unspecified, open-question, or stale-answer specs |
| `tl-propose` | shared propose-not-write machinery → `data/proposals/`, never `lead/` |
| `tl-override-loop` | your corrections → candidate `lead/principles.md` rules |
| `tl-escalation-loop` | worker escalations → candidate `lead/questions.md` entries *(dormant)* |

**Dispatch and supervision**

| | |
|---|---|
| **`tl-spawn`** | dispatch one task into an isolated worktree on `tl/<id>` |
| **`tl-watch`** | the zero-token supervisor; wakes only on actionable events |
| `tl-top` | live read-only fleet dashboard; stop-conditions sorted loud |
| **`tl-state`** | **the only** correct current-state read; reconciles the stale log tail |
| `tl-status` | workers append one wake-worthy transition to the event log |
| `tl-peek` | last N lines of a worker's output, non-invasively |
| `tl-send` | message a running worker (best-effort mailbox — no tmux yet) |
| `tl-escalate` | surface a decision with a stated default; park, don't block |
| `tl-policy` | *(sourced)* the one status→action table every consumer reads |
| `tl-session` | *(sourced)* the session seam — background process + logfile today, tmux later |
| `tl-worktree` | *(sourced)* the only file that knows how worktrees are provisioned |

**Gate and delivery**

| | |
|---|---|
| **`tl-gate`** | tests vs baseline + scope + danger + shortcuts → structured `findings.json` |
| `tl-classify` | pure router: rule-id → class via the rubric. Unknown → `ask-user` |
| `tl-shortcut` | detects `# tl:` shortcuts on danger paths / missing an upgrade path |
| **`tl-deliver`** | self-edit guard + gate, then ff-merge or `gh pr create` |
| `tl-approve` | record your decision on a `plan` report |
| `tl-guard-selfedit` | refuse when the primary checkout is stranded on a `tl/*` branch |
| **`tl-teardown`** | release the worktree; refuses on dirty or undelivered work (`--force`) |

**Review and answer kinds**

| | |
|---|---|
| `tl-review` | both axes in parallel → one draft. Posts nothing, merges nothing |
| `tl-specdiff` | Spec axis — the diff vs the spec's `decided` answers. Also blocks at the gate |
| `tl-standards` | Standards axis — borrowed craft review. Advisory, `review` kind only |
| `tl-answer` | answer your own question from your own record, with citations, or "I don't know" |

**Ledgers and hygiene**

| | |
|---|---|
| `tl-metric` | `report` (grill + approval time) · `outcome` (accept vs correct) |
| `tl-cost` | per-task token cost by category |
| `tl-scrub` | secret guard before content enters `lead/`; fails closed, never strips |
| `tl-common` | *(sourced)* `TL_HOME` capability guard, path resolution, task meta, event log |

---

## Environment reference

| Var | Purpose |
|---|---|
| `TL_HOME` | **Required.** The tool checkout (must contain `bin/` + `AGENTS.md`) |
| `TL_WORKER_CMD` | worker adapter |
| `TL_GRILL_CMD` | grill inference driver |
| `TL_GRILL_PROPOSE_CMD` | question proposer; enables the auto-draft at the empty-bank stop |
| `TL_SCAFFOLD_TEST_CMD` | harness drafter behind `tl-scaffold-test` |
| `TL_SPECDIFF_CMD` | Spec axis — arms the gate's spec check. Unset = the gate silently skips it |
| `TL_STANDARDS_CMD` | Standards axis, `tl-review` only |
| `TL_ANSWER_CMD` | `answer` kind engine |

All seven are written by `tl-init` for the `claude` harness; `opencode` gets the first two.
| `TL_DATA` / `TL_STATE` / `TL_LEAD` / `TL_WORKTREES` | override resolved paths (default: nearest `.techlead/`) |
| `TL_BACKLOG` | backlog path (default `<project>/.techlead/data/backlog.md`) |
| `TL_PROJECTS_DIR` | fixed home for `tl-new` instead of `$PWD` |
| `TL_APPROVE=yes` / `TL_RESOLVE` | non-interactive gate resolution |
| `TL_YES` / `TL_ANSWER_<KEY>` | non-interactive wizards |
| `TL_ANSWER_DECAY_DAYS` | spec-answer staleness threshold (default 30) |
| `TL_WATCH_INTERVAL` / `TL_TOP_INTERVAL` | poll and refresh intervals |
| `TL_OPENCODE_MODEL` | model for the opencode adapters; must support tool-calling |

---

## Five things that will bite you

1. **Uncommitted test harness.** Workers branch from `HEAD`; the gate runs there too. Anything
   uncommitted is invisible to both, and your baseline then measures something neither sees. Commit
   before you dispatch. Both `tl-baseline` and `tl-spawn` warn — don't scroll past it.
2. **`test_command` must print ids, not a summary.** `make test` printing "3 failed" gives the gate
   nothing to diff. Wrap your runner so it emits one identifier per failing test.
3. **`cd` selects the project.** Commands resolve the nearest ancestor `.techlead/`. Run `tl-run`
   from your home directory and it resolves to `TL_HOME` and does the wrong thing quietly.
4. **`lead/` is yours alone.** The LLM proposes; you promote. Never let an agent write into
   `lead/questions.md` or `lead/principles.md` — a bank of borrowed judgment captures nobody, and
   capturing *you* is the entire bet.
5. **The stops are the feature.** If you find yourself reflexively hitting enter through the gate
   findings and pruning nothing from the question bank, you've turned TechLead into an expensive
   `git merge`. The value is concentrated entirely in the three places it refuses to decide for you.
