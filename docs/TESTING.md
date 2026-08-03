# TechLead — Testing (Phase 0)

The tests are plain bash **smoke tests** — no framework, no fixtures directory, no dependencies
beyond `git` and `jq`. Each one is a self-contained, end-to-end check that spins up a throwaway
git repo and a throwaway instance, runs part of the system, asserts, and cleans up. They spend
**zero tokens** (they use the demo drivers, not a real agent).

The rule from the design (§4): the interesting bugs here are timing and state bugs that don't show
up in unit tests. So each smoke exercises a real end-to-end path, and one of them (`watch-smoke`)
asserts the single most important invariant in the system directly.

## Run them

```sh
cd /path/to/techlead
for t in smoke watch-smoke change-smoke grill-smoke onboard-smoke run-smoke; do
  ./test/$t.sh && echo "$t OK" || { echo "$t FAILED"; break; }
done
```

Or individually:

```sh
./test/smoke.sh          # dispatch a plan task end to end
./test/watch-smoke.sh    # the zero-token supervisor + state reconciliation
./test/change-smoke.sh   # the change kind and all its guards
./test/grill-smoke.sh    # backlog → spec → brief
./test/onboard-smoke.sh  # the setup wizards (tl-init / tl-onboard / tl-new)
./test/run-smoke.sh      # tl-spawn arg resolution + the tl-run pipeline driver
```

Each prints its stages and ends with a single `PASS: ...` line and exit code 0. Any `FAIL: ...`
line plus non-zero exit means a broken invariant — the message names which one.

## What each smoke proves

### `smoke.sh` — dispatch (Epic 2 + measurement)
- Spawns a `plan` worker into an isolated worktree on `tl/<id>`; collects `report.md`; approves;
  tears down. Asserts the report **survives teardown** and the worktree is fully removed.
- The teardown **guard**: a worktree with undelivered work refuses teardown; `--force` overrides.
- The cost and metric **ledgers** get a row (E1.4 / E1.5).

### `watch-smoke.sh` — the supervisor (Epic 3) — *the important one*
- Runs one healthy worker and one that raises a mid-task decision, then runs `tl-watch`.
- Asserts the **durable wake queue** captured both a `needs-decision` and a `ready` wake.
- Asserts the **escalation default fired** on owner silence (park-don't-block).
- **The load-bearing check (§3.4):** the blocking worker's event-log tail reads `needs-decision`
  *forever*, yet `tl-state` reports `done`. This proves current state is reconciled from liveness,
  never read from the stale log tail — the bug the whole design exists to avoid.

### `change-smoke.sh` — the change kind (Epic 4)
Four cases against a registered project with a baseline:
- **A.** A clean change passes the gate (0 findings) and **fast-forward-merges** onto `main`.
- **B.** A change that newly fails a test (a **regression** vs baseline) is flagged and **blocks
  delivery** — it never reaches `main`.
- **C.** A change touching >`max_files_changed` files *and* a `danger_paths` glob raises both a
  **scope-cap** and a **danger-path** finding (fail-closed `ask-user`).
- **D.** The **self-edit tangle guard** trips when a `tl/*` worker branch is checked out on the
  primary checkout.

### `grill-smoke.sh` — the grill (Epic 5)
- Grills a backlog item via the demo driver → `spec.md` with a mix of `decided`/`open`/`spike`.
- `tl-brief` **refuses** while a question is `open`.
- The owner answers the delta → `specified` → `tl-brief` now renders the constraints.
- The **reject path** records "don't build this" against the backlog.
- **Decay:** an answer dated in the past forces `tl-brief` to refuse until it's re-confirmed.

### `onboard-smoke.sh` — the setup wizards (Epic 11)
Drives all three wizards **non-interactively** (zero prompts, no live model), asserting the
orchestrator-not-owner contract (§3.1) holds end to end:
- **`tl-init`** writes `config/instance.env`, and a fresh shell auto-loads `TL_WORKER_CMD` from it
  (the W1 round-trip). The real `lead/` is left untouched (seeding declined).
- **`tl-onboard`** registers a brownfield repo **through `tl-project` only** and captures a baseline
  through `tl-baseline` — the `.conf` gets `mode`/`test_command`/`danger_paths` (detected) and
  `readiness=ready`, the path is the canonical toplevel, and the baseline holds the known-failing ids.
- **`tl-new`** creates an **empty** repo under `TL_PROJECTS_DIR` and registers it at
  `readiness=survey` with no `test_command` (plan-only) — proving it scaffolds no app boilerplate.

It redirects `TL_CONFIG` and `TL_PROJECTS_DIR` into the temp sandbox (alongside `TL_DATA`/`TL_STATE`),
so your real `config/` and `projects/` are never touched.

### `run-smoke.sh` — spawn consolidation + the `tl-run` driver
Two related conveniences, proven deterministically (demo-grill + change-worker, no live model):
- **`tl-spawn <id>`** resolves brief/project/kind from existing state (sole registered project;
  readiness→kind); a spec `kind`/`project` field and explicit flags override; and each unresolvable
  case (**no project**, **ambiguous project**, **unresolvable kind**) refuses with the missing piece
  named and dispatches nothing. The full-flag form stays byte-for-byte compatible.
- **`tl-run <slug>`** walks grill→brief→spawn→gate/deliver and **halts at the two owner-judgment
  points** — an `open` spec (or a reject) before dispatch, and unresolved gate findings before merge
  — while auto-advancing the deterministic stages. It hands off to `tl-watch` after spawn (never
  blocks), and is **resumable**: re-invoking recomputes the stage from files + `tl-state` (no driver
  state), so a mid-flight re-run neither re-spawns nor loses its place, and a clean change ff-merges
  while a regression is stopped at the gate.

## Test fixtures (the fake workers/drivers)

These live in `test/` and stand in for a real agent so the smokes are deterministic and free:

| Fixture | Simulates |
|---------|-----------|
| `demo-worker.sh` | A `plan` worker: writes a `report.md`, records a synthetic cost, emits `done`. |
| `block-worker.sh` | A worker that hits an `ask-user` decision, then **silently resumes** — used to create the stale-tail case `tl-state` must reconcile. |
| `change-worker.sh` | A `change` worker: edits `TL_CW_FILES` in its worktree and commits on `tl/<id>`. |
| `demo-grill.sh` | A deterministic grill inference driver (one inferred, one open, one spike). |

Real equivalents are the adapters (`adapters/claude-worker.sh`, `adapters/claude-grill.sh`).

## How the smokes stay isolated

Every smoke:
- creates a **throwaway project** with `mktemp -d` + `git init`, and a **throwaway storage** dir;
- sets `TL_HOME="$REPO"` (so `$TL_HOME/bin` resolves to the real scripts) but redirects
  `TL_DATA` / `TL_STATE` / `TL_WORKTREES` into the temp dir, so **your real `data/`/`state/` are
  never touched**;
- uses a `trap ... EXIT` to `rm -rf` the temp dirs.

Nothing is left behind and no network or real agent is involved.

## Testing against a real agent

### Automated (local model, free) — `test/live-smoke.sh`

```sh
./test/live-smoke.sh                                     # default: ollama/qwen3-coder:30b
TL_OPENCODE_MODEL=ollama/gemma4:26b ./test/live-smoke.sh # try another local model
```

Runs the whole pipeline — backlog → grill → brief → spawn → gate → deliver — through opencode + a
local model, and asserts a farewell function lands on `main`. It is slow (minutes) and asserts the
**outcome**, not exact intermediate output, so it tolerates model non-determinism (e.g. it answers
any question the model leaves `open`, then checks the delivered change). It **skips cleanly**
(exit 0) if opencode or the model isn't installed. The four demo smokes above stay the fast,
deterministic suite; this is the real-local-agent check.

> **If a local-model run hangs, it's usually opencode, not TechLead.** `opencode run` can wedge:
> the process sits holding `~/.local/share/opencode/opencode.db` **without ever loading the model**
> (tell-tale: `ollama ps` shows nothing loaded and CPU is ~0%, yet the grill/worker never returns).
> A stale/orphaned `opencode` process from an earlier aborted run keeps the shared backend wedged,
> so *new* runs block indefinitely too. Recover with `pkill -f opencode` (clear the orphan), then
> retry — or switch to the Claude Code harness (below), which drives the same pipeline reliably.
> The `bin/` scripts run through setup (`tl-init`/`tl-onboard`) fine regardless; the hang is below
> the `TL_WORKER_CMD`/`TL_GRILL_CMD` seam.

### Manual — drive either harness yourself

To exercise a *real* agent end to end by hand. Two harnesses are wired; pick one:

**Claude Code** — spends tokens (~**$0.40** for a tiny change, dominated by Claude Code's fixed
per-invocation context, not the task). Needs `claude` installed and authenticated.

```sh
export TL_HOME="$PWD"
export TL_WORKER_CMD="$TL_HOME/adapters/claude-worker.sh"
export TL_GRILL_CMD="$TL_HOME/adapters/claude-grill.sh"
```

**opencode** — free with a **local** model (slower). Needs a **tools-capable** model; for local
models use **`ollama/qwen3-coder:30b`** (coding-specialized — the only local model validated here).

```sh
export TL_HOME="$PWD"
export TL_WORKER_CMD="$TL_HOME/adapters/opencode-worker.sh"
export TL_GRILL_CMD="$TL_HOME/adapters/opencode-grill.sh"
export TL_OPENCODE_MODEL="ollama/qwen3-coder:30b"   # recommended local model
```

Then, with either set, register + baseline a small throwaway project, add a backlog item, and run
the pipeline:

```sh
bin/tl-grill.sh <slug> && bin/tl-brief.sh <id>
bin/tl-spawn.sh --id r1 --project <path> --project-name <name> --kind change --brief data/<id>/brief.md
bin/tl-watch.sh --once
TL_APPROVE=yes bin/tl-deliver.sh r1
```

Both were validated this way against the same `add-farewell` task and produced an identical change
delivered onto `main` — the agent harness is a swappable seam.

## Adding a smoke test

Copy the shape of an existing one:

1. `set -eu`; a `fail() { echo "FAIL: $1"; exit 1; }` helper.
2. `mktemp -d` a project and a storage dir; export `TL_HOME`/`TL_DATA`/`TL_STATE`/`TL_WORKTREES`;
   `trap 'rm -rf ...' EXIT`.
3. Drive the scripts; assert with `[ ... ] || fail "..."` (use `awk`/`jq` for structured checks —
   avoid embedding literal tabs in `grep`).
4. End with one `echo "PASS: ..."`.

## Gotchas worth knowing (all already handled in the code)

- **macOS bash is 3.2.** Avoid heredocs nested inside `$( )` — that combination breaks the 3.2
  parser. Prefer `--body-file`-style temp files.
- **`/var` vs `/private/var`.** `mktemp` returns `/var/...` but `git` resolves the symlink to
  `/private/var/...`; canonicalize with `pwd -P` before comparing paths.
- **`set -e` + `kill`.** `kill` on an already-exited PID returns non-zero and will abort a script
  under `set -e`; guard with `kill -0 ... && kill ... || true`.
- **BSD vs GNU tools.** The scripts use BSD `stat -f %m` and `date -j -f` (macOS). The `# tl:`
  comments name the GNU swaps (`stat -c %Y`, `date -d`).
