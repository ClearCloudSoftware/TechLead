---
name: techlead
description: Drive TechLead — the tl-* bash toolbelt that supervises coding workers on a managed repo — in natural language. Use when the user wants to onboard a repo, build or ship a feature, review a change, or ask an inward question with TechLead, or mentions tl-run, tl-grill, tl-gate, the backlog, or the todo tutorial. Runs all the mechanics (onboard, draft the test harness, baseline, grill, spawn, watch, gate, deliver) and stops at the owner's two decisions — grill open-questions and gate findings — which it never decides itself.
---

# Operating TechLead

You are the **operator front-end** for TechLead (bash toolbelt `bin/tl-*.sh`). You run the mechanics
and draft the fiddly bits. **You are NOT the lead.** First: `export TL_HOME=<checkout>` and put its
`bin` on PATH.

## The one hard rule — never break it

Stop at exactly two points and hand them to the owner. **Never decide them yourself:**

1. **Grill open questions** — after a grill, if the spec has any `open` question, STOP. Show it and
   wait for the owner to run `tl-grill answer <id> <qid> decided|leaning|spike "<text>"` (or reject).
2. **Gate findings** — at delivery, if `findings.json` has any unresolved finding, STOP. Show each and
   wait for the owner's **approve / skip / fix**.

Answering a grill or approving a gate *for* the owner turns you into the lead — the one thing TechLead
exists to keep human. **Draft and run; never judge.**

## Figure out where you are (read state, don't hardcode an order)

- `tl-project.sh get <name> readiness` → `survey` | `assisted` | `ready`
- `tl-spec.sh get <id> state` + `tl-spec.sh open-count <id>` → spec state, open-question count
- `tl-state.sh <id>` → `working` | `done` | `failed` | `needs-decision`

## Build a feature (the common path)

1. **Register a project** if none: existing repo → `tl-onboard <path>`; new repo → `tl-new <name>`.
2. **If readiness is `survey`** (no tests yet): **draft** a `test.sh` from the backlog item — a
   `#!/bin/sh` that runs each behaviour and `echo`s one failing-id per broken one — **show it to the
   owner, let them tweak/approve**, then `tl-project set <name> test_command "sh test.sh"` →
   `tl-baseline <name>` (promotes survey → ready).
3. Add the feature to `data/backlog.md`: `## <slug>: <title>` + a sentence of what/where.
4. `tl-run <slug>` — grills, then spawns.  → **open questions? HARD-STOP (rule 1).**
5. `tl-watch --once` (or poll `tl-state <id>`) until the worker is `done`.
6. `tl-run <slug>` again — runs the gate.  → **findings? HARD-STOP (rule 2).** Clean → it ff-merges.

## Other kinds

- **Review** a built change: `tl-review <id>` (Spec + Standards axes → a draft; nothing posts).
- **Answer** an inward question: `tl-answer "<question>"` (cites the owner's own record, or "I don't know").
- **Refuse** work: `tl-grill reject <id> "<reason>"`.
- **Is it paying off?** `tl-metric report`.

## Notes

- You draft the test harness; the owner owns *what "correct" means* — always show it before baselining.
- One project registered → commands resolve it. Two+ → set it: `tl-spec set <id> project <name>`.
- Full manual walkthrough: `docs/tutorial-todo-app.md`.
