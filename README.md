# TechLead

A persistent senior-tech-lead agent (`lead`) that supervises a crew of autonomous coding
agents (`worker`s) in isolated git worktrees, on behalf of one `owner`. Bash scripts + markdown
prompt files — no daemon, no SQLite, no LLM in the supervision loop.

- **`AGENTS.md`** — the operating contract. Start here.
- **`bin/tl-*.sh`** — the deterministic toolbelt.
- **`lead/`** — the judgment layer (Phase 0 stub; the actual product).

## Phase 0 (working)

The full pipeline runs end to end for `plan` and `change` kinds:

```
backlog → grill → spec → brief → spawn → worktree → worker → watch → gate → deliver
```

- **How to use it:** [docs/USAGE.md](docs/USAGE.md)
- **How to test it:** [docs/TESTING.md](docs/TESTING.md)
- **Tutorial — build a todo app on a free local model:** [docs/tutorial-todo-app.md](docs/tutorial-todo-app.md)

Quick check (no agent, no tokens):

```sh
export TL_HOME="$PWD"
for t in smoke watch-smoke change-smoke grill-smoke; do ./test/$t.sh || break; done
```

## Where the plan lives
- Backlog: GitHub issues on this repo (epics + tasks).
- Scope of record: the *Grilling Session Decisions* doc — the full design is aspirational.
