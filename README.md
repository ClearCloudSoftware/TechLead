# TechLead

A persistent senior-tech-lead agent (`lead`) that supervises a crew of autonomous coding
agents (`worker`s) in isolated git worktrees, on behalf of one `owner`. Bash scripts + markdown
prompt files — no daemon, no SQLite, no LLM in the supervision loop.

- **`AGENTS.md`** — the operating contract. Start here.
- **`bin/tl-*.sh`** — the deterministic toolbelt.
- **`lead/`** — the judgment layer, the actual product. No longer a stub: architecture priors in
  `lead/principles.md` (seeded from real grills, with reuse counters) + the required shape in `lead/SHAPE.md`.

## Phase 0 (working)

The full pipeline runs end to end for `plan` and `change` kinds:

```
backlog → grill → spec → brief → spawn → worktree → worker → watch → gate → deliver
```

- **Start a new project:** [docs/GREENFIELD.md](docs/GREENFIELD.md) — zero to one shipped feature, worked end to end
- **Command reference:** [docs/USAGE.md](docs/USAGE.md)
- **Tests:** plain bash smoke tests under `test/` — run `./test/smoke.sh` (and the other `*-smoke.sh`).

Quick check (no agent, no tokens):

```sh
export TL_HOME="$PWD"
for t in smoke watch-smoke change-smoke grill-smoke prompt-smoke; do ./test/$t.sh || break; done
```

## Where the plan lives
- Backlog: GitHub issues on this repo (epics + tasks).
- Scope of record: the *Grilling Session Decisions* doc — the full design is aspirational.
