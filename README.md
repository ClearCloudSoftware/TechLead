# TechLead

A persistent senior-tech-lead agent (`lead`) that supervises a crew of autonomous coding
agents (`worker`s) in isolated git worktrees, on behalf of one `owner`. Bash scripts + markdown
prompt files — no daemon, no SQLite, no LLM in the supervision loop.

- **`AGENTS.md`** — the operating contract. Start here.
- **`bin/tl-*.sh`** — the deterministic toolbelt.
- **`lead/`** — the judgment layer (Phase 0 stub; the actual product).

## Phase 0 tracer bullet (working)

Dispatch one `plan` task into an isolated worktree, collect its report, approve, tear down —
end to end, no supervision loop or grill yet.

```sh
export TL_HOME="$PWD"
export TL_WORKER_CMD="$PWD/test/demo-worker.sh"   # swap for a real agent CLI later
test/smoke.sh
```

## Where the plan lives
- Backlog: GitHub issues on this repo (epics + tasks).
- Scope of record: the *Grilling Session Decisions* doc — the full design is aspirational.
