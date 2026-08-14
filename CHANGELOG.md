# Changelog

All notable changes to TechLead are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning is
[SemVer](https://semver.org) — `feat:` → minor, `fix:`/`chore:`/`docs:`/`refactor:` → patch,
breaking → major — and is **hand-cut**, not automated: a tag means the release ran a week of real
use (§4).

## [Unreleased]

### Changed

- **`tl-baseline`, `tl-scaffold-test`, `tl-scaffold-context` infer the project** from the current
  `.techlead` when no `<name>` is given (per-project state means one per repo), like `tl-kickoff` —
  no more retyping the name you're standing in. They refuse with a clear message when zero or more
  than one project is registered (`test/infer-project-smoke.sh`).

### Added

- **`tl-scaffold-context`** — drafts a project's `AGENTS.md` (layout, conventions, danger zones) and
  `CONTEXT.md` (domain glossary) as real files (draft-then-approve: never commits, never overwrites),
  closing the gap where the onboarding survey (a plan task) could only *describe* them in a report.
  The grill now feeds the committed `AGENTS.md` + `CONTEXT.md` to its driver, so inferences use the
  project's own vocabulary. Completes Epic 9 / #60 (`test/scaffold-context-smoke.sh`).
- **`tl-kickoff`** — greenfield project ideation as a **terminal interview**. Runs entirely from the
  shell (no Claude Code app): each turn is a discrete `claude -p` call, the conversation lives in a
  transcript file (killable/resumable, §3.2). When it has enough it drafts `CONTEXT.md` (uncommitted,
  no overwrite) + prints ready `tl-backlog add` lines — both owner-approved. `<project>` is inferred
  from the current `.techlead`. The greenfield complement to `tl-scaffold-context`; never writes
  `AGENTS.md` (`test/kickoff-smoke.sh`).
- **Answer the grill in the terminal** — `tl-grill answer <id>` with no qid walks the open questions
  one at a time (pick a state, type the answer) instead of retyping the full command per question,
  and `tl-grill prune <slug>` multi-selects which proposed questions survive instead of editing the
  proposal file by hand. Both go through the existing single writer, so the correction log and the
  D13 metric are unchanged. No tty → both refuse rather than rubber-stamp (`test/prompt-smoke.sh`).
- **`tl_text` / `tl_pick_many` prompt helpers** in `tl-wizard.sh`, on the same optional-enhancement
  seam as `tl_choose`: [`gum`](https://github.com/charmbracelet/gum) → `fzf` → numbered menu. Neither
  is required. Gate finding resolution now uses the shared picker too.
- **Tables wrap instead of truncating.** Neither `gum table` nor its `--widths` wraps, so a long
  question was simply cut off — the one thing a decision table must not do. The renderer now wraps
  the widest column to whatever width the fixed columns leave and lets the row grow taller (gum
  accepts newlines inside a quoted CSV field; the plain form continues on further lines with its
  neighbours blank). Wrapping is skipped when not decorating, so captured output keeps one line per
  record.
- **`tl_table`** — question lists (`tl-grill`, `tl-run`'s open-question stop), gate findings, and the
  ledgers (`tl-cost report`, `tl-metric report`/`outcome`) render as a `gum table` when gum is
  installed and stdout is a terminal, and as a width-measuring aligned table otherwise. Captured
  output stays whitespace-columned, so `tl-cost report | awk '$1=="worker"{print $2}'` still parses;
  the machine-readable forms (`tl-spec qlist`'s pipe encoding, `findings.json`) are untouched.
  `TL_NO_TABLE=1` forces the plain form (also useful in the rare pty that never answers
  terminal queries, where gum would block).
- **`tl_spin`** — the steps that used to go silent for tens of seconds now show a spinner: the test
  suite in `tl-baseline` and `tl-gate`, the grill driver, the proposer, the answer engine, and the
  spec-axis judge. Callers keep their own redirections inside the command, so nothing that gets
  parsed passes through the spinner.
- **`tl_page`** — `tl-approve`, `tl-grill show`, `tl-review`, and `tl-answer` page their output when
  it does not fit, and render markdown through `glow`/`gum format`. `tl-approve` in particular used
  to `cat` a long report and then print the approve/skip/fix prompt below it, so the evidence and the
  decision were never on screen together.
- **`tl-kickoff` and `tl-scaffold-context` get the same treatment** — the interview frames each
  question so the lead's turn is visibly not your own typing, runs each model call under a spinner,
  and *shows* the drafted `CONTEXT.md`/`AGENTS.md` rendered instead of telling you to go open them.
  The seed backlog is now a multi-select that adds what you pick (the same curate-then-commit shape
  as `tl-grill prune`); the copy-paste `tl-backlog add` lines are still printed, so nothing is lost
  and the non-interactive contract is unchanged.
- **Fuzzy pickers for omitted arguments** — `tl-peek`, `tl-approve`, `tl-deliver`, `tl-teardown` pick
  a task id from the live fleet; `tl-run` picks a backlog slug; `tl-onboard` browses for a repo
  directory; `tl-new` prompts for a name. Non-interactively they still print usage and exit.
- **Read-only findings navigator** in `tl-gate` when a gate produces more than five findings —
  select a row to read it in full. Deliberately *not* a resolve UI: §2.3.1 makes that gate a
  one-at-a-time chokepoint, and a selectable list is how bulk-approving starts.
- **Colourised output** — `tl_stop`/`tl_ok`/`tl_kv`/`tl_note` in `tl-common.sh` give refusals,
  successes, and next-step lines distinct weight. Only when stdout is a terminal; `NO_COLOR` honoured,
  so piped and captured output is byte-identical to before.
### Fixed

- **The smoke suite inherited `config/instance.env`.** Every test exports `TL_HOME=$REPO`, and
  `tl-common` loads `$TL_HOME/config/instance.env` from it — so once `tl-init` had been run in a
  checkout, the tests silently picked up the real Claude adapters. Assertions about "no scaffolder
  configured" started failing, and worse, a smoke run could call a model and spend tokens. Tests are
  now hermetic (`TL_CONFIG=`), and `TL_CONFIG` honours an explicit empty value (`${TL_CONFIG-…}`,
  not `:-`) so that opt-out exists at all.

- **`tl-gate` silently discarded its own refusal.** `exec 3</dev/tty 2>/dev/null` applies *both*
  redirections to the shell permanently, so once the interactive resolve branch was taken every
  later stderr write went to `/dev/null` — including `gate blocked: N finding(s) unresolved`. An
  owner sitting at a terminal who marked a finding `fix` got exit 3 and no explanation. The exec is
  now brace-grouped so the silencing is scoped to it.

## [0.3.0] — 2026-08-14

Per-project state, the greenfield loop end to end, and the judgment layer's reuse signal made
automatic. Still Phase 0. LLM adapters draft (grill, propose, scaffold, review); the owner approves —
nothing crosses into deciding what "correct" means without a human.

### Changed

- **BREAKING — per-project state.** `TL_HOME` is now the tool install only (`bin/`, `adapters/`,
  `AGENTS.md`, `config/`); each managed repo keeps its own `data/`, `state/`, and `lead/` under
  `<project>/.techlead/`, resolved by walking up from `$PWD` to the nearest `.techlead/` (the
  `.claude`/`.superpowers` convention). Being *in* the project selects it — the old multi-project
  resolution ambiguity is gone. `tl-new`/`tl-onboard` scaffold `.techlead/`; `tl-init` no longer
  seeds `lead/`. Existing central state is not migrated. (#98; design §3.2 rewritten.)

### Added

- **Grill propose-mode** — on a thin/empty `lead/questions.md`, `tl-grill propose <slug>` drafts
  candidate questions to `data/proposals/`; the owner prunes and `tl-grill promote <slug>` seeds the
  bank (provisional: `hits: 0`, unproven scar). `tl-run` auto-drafts at the empty-bank stop when a
  proposer is configured. Nothing enters `lead/` without an explicit promote. (#100)
- **`tl-scaffold-test`** — drafts a greenfield project's `test.sh` from its backlog (failing-id-per-
  line contract) and sets `test_command`, then stops for owner review; never baselines/promotes and
  never overwrites an existing harness (`test/scaffold-test-smoke.sh`). (#102)
- **`tl-backlog`** — `add <slug> "<title>" [desc]` appends a validated, grill-matchable item (rejects
  a bad or newline slug/title, no duplicates, restores a missing `# Backlog` header); `list` shows the
  queue (`test/backlog-smoke.sh`). (#108)
- **Automatic `hits:` reuse counter** — a grill bumps the `questions.md` entries it drew answers from,
  and a review bumps the `review-rubric.md` rules its findings cited (the driver reports which via a
  numbered ref; `bump_hits` in `tl-common.sh` is the single owner of the write). The D13 / risk-1
  reuse signal is no longer hand-kept. (#107, #109)
- **Memory-hygiene conventions for `lead/`** — a consolidation routine (four tiers, a cadence
  trigger, promote/merge/**delete**) and a write-time contradiction check (keep/merge/supersede,
  superseded rules removed) in `lead/SHAPE.md`; plus a context-budget ceiling (~200 lines / ~20K
  tokens per always-loaded file) in `AGENTS.md`. Convention only, lifted from an evaluated-and-
  rejected memory tool — no dependency or runtime.
- **`tl-scrub`** — a deterministic deny-pattern guard that scans content entering `lead/`/`decisions/`
  for keys, tokens, credentials, and internal hostnames; on a hit it escalates for owner review and
  never strips (`test/scrub-smoke.sh`).

### Fixed

- **Fail closed on un-grilled work** — `tl-run` refuses to dispatch a spec with zero grilled questions
  (an empty question bank) instead of silently spawning a worker on an empty spec. (#99)
- **Gate fails closed on an unrunnable harness** — the change gate captured the pipe's exit status,
  not the test command's, so a missing/broken harness read as "0 failures → pass"; it now raises a
  blocking `test-harness-unrunnable` finding. (#105)
- **Harness-visibility warnings** — `tl-baseline`/`tl-spawn` warn when the project tree is dirty,
  because a worker's worktree branches from `HEAD` and can't see an uncommitted test harness. (#101)
- **Local-only teardown** — `tl-teardown`'s delivered-guard keyed on `pr`, refusing every ff-merge
  (local-only, tl-new's default) delivery; it now keys on `delivered`, which both delivery paths set.
  (#104)
- **Per-project answer corpus** — `tl-answer` still read grill specs from `$TL_HOME/data` (a line the
  #98 migration missed); it now globs `<project>/.techlead/data`. (#104)
- **Gate/review/answer judges wired** — `tl-init` now sets `TL_SPECDIFF_CMD` / `TL_STANDARDS_CMD` /
  `TL_ANSWER_CMD` for the claude harness; unset, the gate's Spec axis (its differentiator) was
  silently skipped. (#104)

## [0.2.0] — 2026-08-03

The **judgment layer comes alive** (Epic 6) alongside new fleet tooling. Still Phase 0.

### Added

- **`lead/` judgment layer, seeded** — three architecture priors in `lead/principles.md`, each with a
  per-rule hit counter, extracted from four hand-run grills on TechLead's own features; the required
  shape in `lead/SHAPE.md`, plus the grill question bank and an ADR template (Epic 6, Track B).
- **Inferred-answer outcome tracking** — `tl-grill` logs corrections to `data/inferred-outcomes.tsv`,
  `tl-metric outcome` reports the per-grill accept/correct signal (the risk-1 metric), and `spec.md`
  gains an `outcome:` field for lite outcome notes.
- **`tl-run`** — pipeline driver that resolves `tl-spawn` arguments from state.
- **`tl-top`** — read-only curses fleet view.

### Changed

- Versioning switched from phase-tracking to plain SemVer (see the header above).

## [0.1.0] — 2026-08-03

First tagged release. **Phase 0** (the plumbing) plus the **guided setup wizard** (Epic 11).
Supports the `plan` and `change` task kinds, terminal-only, on a single machine.

### Added

- **Dispatch loop** — spawn a task into an isolated `git worktree` on branch `tl/<id>`, supervise
  it, and tear it down; the report survives teardown (`tl-spawn`, `tl-peek`, `tl-send`,
  `tl-teardown`).
- **Zero-token supervisor** — the watcher classifies the fleet with `kill -0`/`stat`, reconciling
  current state from liveness rather than the append-only event-log tail (`tl-watch`, `tl-state`).
- **`change` kind** — delivery gate (tests vs. a recorded baseline, scope cap, danger paths),
  self-edit tangle guard, and fast-forward-merge / PR delivery (`tl-gate`, `tl-deliver`,
  `tl-baseline`, `tl-project`).
- **The grill** — backlog → spec → brief with an inference pass, a reject path, and answer-decay
  refusal (`tl-grill`, `tl-spec`, `tl-brief`).
- **Cost and metric ledgers** (`tl-cost`, `tl-metric`).
- **Swappable agent-harness adapters** — Claude Code and opencode, for both worker and grill,
  behind the `TL_WORKER_CMD` / `TL_GRILL_CMD` seam.
- **Guided setup wizard (Epic 11):**
  - `tl-init` — instance config (harness, model, `TL_PROJECTS_DIR`, optional `lead/` skeleton) →
    `config/instance.env`, auto-loaded by `tl-common` (shell env still wins).
  - `tl-onboard` — brownfield: register an existing repo in place and capture a baseline
    (`readiness=ready`), then offer to dispatch the survey plan task.
  - `tl-new` — greenfield: create an empty repo under `TL_PROJECTS_DIR`, registered at
    `readiness=survey` (plan-only).
  - `tl-detect` — best-effort defaults (mode / branch / test-command / danger-paths).
  - Fully non-interactive via `--yes` and `TL_ANSWER_*`. The wizards call `tl-project`/`tl-baseline`
    and never write the registry themselves (§3.1).
- **Docs** — USAGE and TESTING guides, plus a local-model todo-app tutorial.
- **Smoke suite** — `smoke`, `watch-smoke`, `change-smoke`, `grill-smoke`, `onboard-smoke`
  (deterministic, token-free via demo drivers), plus an opt-in live integration smoke.

### Known limits

- `plan` and `change` only — the `review` and `answer` kinds arrive in Phase 1 (Epics 8–9).
- Terminal-only (no Slack), single machine, plain `git worktree` (no pool).
- The `lead/` judgment layer is a stub — rules accrete from real grills, not borrowed principles.
- opencode local-model runs can hang intermittently (see `docs/TESTING.md`).

[0.1.0]: https://github.com/ClearCloudSoftware/TechLead/releases/tag/v0.1
