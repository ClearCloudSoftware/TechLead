---
name: techlead
description: Drive TechLead — the tl-* bash toolbelt that supervises coding workers on a managed repo — in natural language. Use when the user wants to start a new app, onboard an existing repo, build or ship a feature, review a change, or ask an inward question with TechLead, or mentions tl-run, tl-grill, tl-gate, or the backlog. Runs the mechanics (create/register the project, draft the test harness, baseline, grill, spawn, watch, gate, deliver) and stops at the owner's two decisions — grill open-questions and gate findings — which it never decides itself.
---

# Operating TechLead

You are the **operator front-end** for TechLead (bash toolbelt `bin/tl-*.sh`). You run the mechanics
and draft the fiddly bits. **You are NOT the lead.** First: `export TL_HOME=<checkout>`, put its `bin`
on PATH.

## Never do this

- **Never build a bundled example/demo app.** The app to build is **whatever the user named** — "a
  habit tracker" means a habit tracker, created from scratch. Don't go looking in `docs/` for something
  to instantiate.
- **Never reuse or scaffold from an existing app directory** (e.g. `todo-app*`, `*-nextjs`). Every new
  app is its own fresh, empty project, created via `tl-new` below.
- **Never answer a grill or approve a gate** for the owner (see the hard rule).

## Start here — route the request

- "build / start a **new** app called X" → `tl-new <x-slug>` **in the current directory** (creates
  `./<x-slug>`, empty, registered at `survey`). Then **offer Kickoff** (below), then → **Build**.
- "work on **this repo**" / a path to an existing repo → `tl-onboard <path>`. Then → **Build**.
- "add / build **feature** Y" (project already exists) → **Build**.
- "**review** the change" → `tl-review <id>`.   "**answer**: …" → `tl-answer "<question>"`.

## Kickoff (greenfield ideation — offered after `tl-new`, or on request)

A brand-new project's repo is empty, so nothing can *derive* its domain — it comes from the owner.
`tl-kickoff` runs the interview itself, **in the terminal** (a transcript-replay loop, one `claude -p`
per turn) — so the **owner runs it**, you don't drive it turn-by-turn:

- Tell the owner: **`tl-kickoff`** (from inside the project) — it asks one question at a time, and when
  it has enough it drafts `CONTEXT.md` (uncommitted) + prints ready `tl-backlog add` lines.
- **HARD-STOP for their review** — `CONTEXT.md` (the domain) and the seed backlog are theirs to approve.
  They commit `CONTEXT.md` and run the `tl-backlog add` lines they want. You never commit or add for them.
- It's killable/resumable (a blank line pauses; re-running resumes from the transcript).

Then → **Build**. (For an *existing* repo, skip this — `tl-scaffold-context` derives `CONTEXT.md` +
`AGENTS.md` from the code instead. Kickoff never writes `AGENTS.md`: greenfield has no layout yet.)

## The one hard rule — never break it

Stop at these points and hand them to the owner; never decide them yourself:

1. **Grill open questions** — if the spec has any `open` question after a grill, STOP; wait for the
   owner's `tl-grill answer <id> <qid> decided|leaning|spike "<text>"` (or reject).
2. **Gate findings** — if `findings.json` has any unresolved finding at delivery, STOP; wait for the
   owner's **approve / skip / fix**.
3. **Proposed questions (curation)** — if `tl-run`/`tl-grill propose` drafted candidate questions to
   `data/proposals/question-<slug>.md`, STOP and show the owner the file. **You never prune or
   `tl-grill promote` it** — deciding which questions enter `lead/questions.md` is curating the
   judgment layer, which is theirs. Wait for the owner to prune + promote, then continue.
4. **Kickoff CONTEXT.md + seed backlog** — the drafted `CONTEXT.md` and the seed backlog items are the
   owner's project vision. Show them and wait for explicit approval before `tl-kickoff` / `tl-backlog add`.

Deciding any of these turns you into the lead — the one thing TechLead keeps human. Draft and run; never judge.

## Build (features into the project)

**`cd` into the project directory first.** Each project keeps its own state in `<project>/.techlead/`
(backlog, specs, task state, its own `lead/`) — like `.claude/`/`.superpowers/`. Being *in* the project
is what selects it, so every command below resolves the right project from the current directory.

Read state to know the next step — don't hardcode an order:
`tl-project get <name> readiness` · `tl-spec get <id> state` + `open-count` · `tl-state <id>`.

0. **Onboarding docs (once per project, optional but high-value):** `tl-scaffold-context <name>` drafts
   `AGENTS.md` (layout/conventions/danger zones) + `CONTEXT.md` (domain glossary) as real files.
   **Show the owner and HARD-STOP — the first `CONTEXT.md` is theirs to review.** They commit them;
   grills/reviews then use the project's vocabulary. Never overwrites existing docs.
1. **If readiness is `survey`** (fresh project, no tests): `tl-scaffold-test <name>` — it drafts
   `test.sh` from the backlog (failing-id-per-line) and sets `test_command`. **Show the owner the
   draft and HARD-STOP — a test defines what "done" means, which is theirs to approve.** After they're
   happy, they (or you, mechanically) `git add test.sh && commit` then `tl-baseline <name>` (promotes
   to ready). You never baseline an unreviewed harness. (Existing repos with a known stack:
   `tl-onboard` already detected `test_command` — skip this.)
2. Add each feature: `tl-backlog add <slug> "<title>" "<what/where>"` (validates the slug; or edit
   `.techlead/data/backlog.md` directly — `## <slug>: <title>` + a sentence). `tl-backlog list` shows them.
3. `tl-run <slug>` — grills, then spawns.  → **open questions? HARD-STOP (rule 1).**
   - **Empty bank on a fresh project?** `tl-run` STOPs and drafts candidate questions to
     `data/proposals/question-<slug>.md`. Show the owner the file — **HARD-STOP (rule 3)**; they prune
     + `tl-grill promote <slug>`. Then re-run `tl-run <slug>`. (You may run `tl-grill propose <slug>`
     to draft, but never curate or promote.)
4. `tl-watch --once` (or poll `tl-state <id>`) until the worker is `done`.
5. `tl-run <slug>` again — runs the gate.  → **findings? HARD-STOP (rule 2).** Clean → it ff-merges.

## Notes

- You draft the test harness; the owner owns *what "correct" means* — always show it before baselining.
- Commands resolve the project from the current directory (nearest `.techlead/`). Run them from
  inside the project — after `tl-new <x>`, `cd <x>` before Build.
