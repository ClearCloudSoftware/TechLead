---
id: tl-spec-diff-checker
backlog: e8.2
title: Spec-diff checker (the Spec review axis)
state: specified
grilled_at: 2026-08-03
outcome:
q: q1|decided|owner|2026-08-03|A difference is flagged as a function of the question's firmness marker: decided contradicted -> LOUD flag (real violation); leaning diverged -> NOT a violation (worker may challenge a lean; quiet FYI at most); open resolved-in-code -> gentle flag (unagreed decision, should have returned to owner); spike -> no violation, surface the landed outcome for owner review. Stops the robot crying wolf on every divergence.
q: qi1|decided|inferred|2026-08-03|Review = two parallel sub-agents: Standards (borrowed /code-review; source review-rubric.md + project AGENTS.md) + Spec (built; source data/<id>/spec.md). Run apart so nits don't drown intent. §2.2/D6 [accepted]
q: qi2|decided|inferred|2026-08-03|Spec axis diffs a finished PR against spec.md stable question IDs and flags where the change disagrees with the decided answers. §2.2/§6.4/#54 [accepted]
q: qi3|decided|inferred|2026-08-03|Only possible because the grill produces a durable spec with stable qids — the grill is the strategic centre (§6.4 gap 2). [accepted]
q: qi4|decided|inferred|2026-08-03|Findings tie to spec qids; a recurring finding becomes a new lead/questions.md entry. §3.13/§2.6 [accepted]
q: qi5|decided|inferred|2026-08-03|review kind is draft-only — the Spec axis proposes, the owner disposes. §2.2/E8.6 [accepted]
q: q2|decided|owner|2026-08-03|LLM judgment checker: a sub-agent reads the diff and calls satisfied/violated/can't-tell per decided question. A script does only coverage bookkeeping (which qids exist, did the PR touch them). Consistent with "router not detector" — the Spec axis is a legit detector: keep it draft-only, its findings don't leak into the mechanical gate.
q: q3|decided|owner|2026-08-03|Reports PER-DECISION, never one overall verdict: each decided question is satisfied / violated / can't-evaluate. "Can't-evaluate" is first-class (as loud as a violation) — no silent pass. A clean review means "N of N genuinely checked & satisfied", not "nothing printed". [reuse of principles rule "Make emptiness legible" -> hits 2]
q: q5|decided|owner|2026-08-03|CORRECTION of lead's rule-1 rec (draft-only): the Spec axis runs on EVERY change's delivery gate; a decided-violation is an ask-user finding that BLOCKS the merge (via #55). It also runs standalone in the review kind (draft-only). Two homes. Cost accepted: every change delivery runs the LLM Spec check + can block. Judgment stays in the named Spec detector (not leaked into mechanical rules), so risk-17 still holds.
q: q4|decided|owner|2026-08-03|Non-goal violation = LOUD flag (a non-goal is a decided "no"). Incidental/unrelated code with no matching decision = NOT the Spec axis's job (would fire on nearly every PR) — that's mechanical scope-cap/danger + Standards. Don't pre-build "unasked-feature" detection (rule 1, applied correctly); add if it bites.
q: q6|decided|owner|2026-08-03|Failure to avoid: unverifiable verdicts — it blocks your merge on "q3 violated" but you can't see why, so you rubber-stamp or turn it off (both kill the differentiator). Done: (1) per-question ✓/✗/? ; (2) every verdict SHOWS ITS WORK — q-id + exact diff lines + one-line why (a blocking verdict you can't audit isn't done); (3) runs on every change (decided-violation blocks via #55) + standalone review (draft); (4) marker-driven loudness, non-goals loud, script=bookkeeping / LLM=judgment. Non-goals: no leaning/open/incidental as violations, no unasked-feature detection, judge is prompted not trained.
---
# Spec-diff checker (the Spec review axis)

_Backlog:_ GitHub #54 (E8.2) · _Parent:_ Epic 8 (#9) · _Grill:_ E6.1 grill #2, 2026-08-03 · **specified**

The differentiator (§6.4): nobody else can review for *intent*, because nobody else has a grill that
produces a durable spec with stable question IDs to check the code against.

## Definition of done (v1)
1. Per decided question: ✓ satisfied / ✗ violated / ? couldn't-evaluate (q3).
2. **Every verdict shows its work** — the q-id checked + the exact diff lines judged + a one-line why.
   A blocking verdict you can't audit isn't done.
3. Runs on **every change** (a decided-violation blocks as an ask-user via #55) **and** standalone in
   `review` (draft-only) (q5).
4. Marker-driven loudness (q1); non-goals are loud (q4); script does coverage bookkeeping, an LLM
   sub-agent makes the satisfied/violated/can't-tell call (q2).

## Non-goals (v1)
Doesn't treat `leaning` / `open` / incidental code as violations; no unasked-feature detection; the
judge is a *prompted* sub-agent (spec + diff), nothing trained. The Spec axis originates findings but
keeps judgment in itself (not leaked into mechanical gate rules) — the risk-17 guard (#53/#54) holds.
