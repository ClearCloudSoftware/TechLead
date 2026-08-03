# Changelog

All notable changes to TechLead are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning tracks build phases —
`v0.1` = Phase 0, `v0.2` = Phase 1, … `v1.0` when all four task kinds ship — and is **hand-cut at
phase boundaries**: a tag means the release ran a week of real use (§4).

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
