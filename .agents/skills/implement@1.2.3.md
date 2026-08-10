# Vendored (pinned reference): implement — mattpocock-skills @ 1.2.3

> Source: `mattpocock-skills:implement` (claude-plugins-official), pinned **v1.2.3**.
> Vendored per §3.14 for **provenance only** — an upstream change arrives as a reviewable diff
> to this file. This is a reference copy, **not wired into any adapter** (TechLead adapters keep
> their own prompts). Do not edit to encode local judgement — that lives in `lead/`.

---- upstream SKILL.md (verbatim) ----

---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.
