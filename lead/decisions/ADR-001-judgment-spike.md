# ADR-001: The judgment layer captures the owner — early evidence (Epic 6 spike)

**Date:** 2026-08-03 · **Status:** accepted (early read; the formal feature-15 kill-gate is still ahead)

## Context

Risk 1 (§8.1) is the project's highest-stakes unknown: does `lead/` actually capture the owner's
judgment, or does it converge on a plausible generic style guide (risk 26)? Epic 6 tested this by
hand — four facilitated grills on TechLead's own features, with the owner supplying every judgment
call and no scripts driving the judgment (D2). This records what the spike found.

## Decision

Treat risk 1 as tentatively resolved in the positive and continue the judgment-layer approach into
Phase 1. The four grills produced a **small, reused core** of rules rather than a junk drawer of
one-offs — the signal D4 names as "working." The formal kill-gate decision (D13) is **not** made
here; it waits for the missing input noted below at ~feature 15.

## Evidence

Four grills — #55 finding-classification, #54 spec-diff, #59 inward-answer, #60 CONTEXT.md:

- **Rules born:** 3, all in grill 1. Grills 2–4 minted **zero** new rules — pure reuse. A stable rule
  set across unrelated features is the opposite of the "generic engineer with a notebook" failure.
- **Per-rule reuse** (`lead/principles.md` hit counters):
  - *Make emptiness legible* — **4 uses, 4 domains** (classification, review, retrieval, glossary).
  - *Let it ask, don't pre-automate* — **2 uses**; born, owner-corrected mid-spike, sharpened, then
    fired clean. A rule that survived being wrong.
  - *Router, not detector* — **1 use**; on probation, prune candidate if it doesn't fire in 2–3 more grills.
- **Inferred-answer accuracy** (`tl-metric outcome`, `data/inferred-outcomes.tsv`): 21/22 accepted,
  1 genuine owner correction — high, but not a rubber stamp; the correction proves real engagement.

## Consequences

- Confidence that grilling extracts reusable judgment, not a commodity checklist. Proceed to spec the
  Phase 1 judgment layer (Epic 7) and Spec review (Epic 8); their first grills are already recorded.
- **Missing kill-gate input:** D13 weighs reuse *and* grill+approval **time** vs. do-it-myself time.
  Only reuse is instrumented. Hand-run in a chat, the time number is untrustworthy — it needs a real
  timer once scripts drive the loop. The formal continue/stop decision waits on that data.
- Prune *Router, not detector* if it stays at one use after the next grills.

## Provenance

Grill specs: `data/tl-finding-classification`, `data/tl-spec-diff-checker`, `data/tl-inward-answer`,
`data/tl-project-context`. Decisions also recorded on GitHub issues #55 / #54 / #59 / #60; E6.1
summary on #42.
