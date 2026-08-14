# Changelog

All notable changes to TechLead are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning is
[SemVer](https://semver.org) — `feat:` → minor, `fix:`/`chore:`/`docs:`/`refactor:` → patch,
breaking → major — and is **hand-cut**, not automated: a tag means the release ran a week of real
use (§4).

## [Unreleased]

### Added

- **Answer the grill in the terminal** — `tl-grill answer <id>` with no qid walks the open questions
  one at a time (pick a state, type the answer) instead of retyping the full command per question,
  and `tl-grill prune <slug>` multi-selects which proposed questions survive instead of editing the
  proposal file by hand. Both go through the existing single writer, so the correction log and the
  D13 metric are unchanged. No tty → both refuse rather than rubber-stamp (`test/prompt-smoke.sh`).
- **`tl_text` / `tl_pick_many` prompt helpers** in `tl-wizard.sh`, on the same optional-enhancement
  seam as `tl_choose`: [`gum`](https://github.com/charmbracelet/gum) → `fzf` → numbered menu. Neither
  is required. Gate finding resolution now uses the shared picker too.
- **`tl_table`** — question lists (`tl-grill`, `tl-run`'s open-question stop) and gate findings render
  as a `gum table` when gum is installed, and as a width-measuring aligned table otherwise. The
  machine-readable forms (`tl-spec qlist`'s pipe encoding, `findings.json`) are untouched — only the
  display changed. `TL_NO_TABLE=1` forces the plain form; gum truncates long cells rather than wrapping.
- **Colourised output** — `tl_stop`/`tl_ok`/`tl_kv`/`tl_note` in `tl-common.sh` give refusals,
  successes, and next-step lines distinct weight. Only when stdout is a terminal; `NO_COLOR` honoured,
  so piped and captured output is byte-identical to before.

### Fixed

- **`tl-gate` silently discarded its own refusal.** `exec 3</dev/tty 2>/dev/null` applies *both*
  redirections to the shell permanently, so once the interactive resolve branch was taken every
  later stderr write went to `/dev/null` — including `gate blocked: N finding(s) unresolved`. An
  owner sitting at a terminal who marked a finding `fix` got exit 3 and no explanation. The exec is
  now brace-grouped so the silencing is scoped to it.

- **Memory-hygiene conventions for `lead/`** — a consolidation routine (four tiers, a cadence
  trigger, promote/merge/**delete**) and a write-time contradiction check (keep/merge/supersede,
  superseded rules removed) in `lead/SHAPE.md`; plus a context-budget ceiling (~200 lines / ~20K
  tokens per always-loaded file) in `AGENTS.md`. Convention only, lifted from an evaluated-and-
  rejected memory tool — no dependency or runtime.
- **`tl-scrub`** — a deterministic deny-pattern guard that scans content entering `lead/`/`decisions/`
  for keys, tokens, credentials, and internal hostnames; on a hit it escalates for owner review and
  never strips (`test/scrub-smoke.sh`).

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
