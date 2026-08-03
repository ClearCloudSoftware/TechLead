---
id: tl-finding-classification
backlog: e8.3
title: Finding classification (auto-fix vs ask-user)
state: specified
grilled_at: 2026-08-03
outcome:
q: q1|decided|owner|2026-08-03|v1 ships the classification MECHANISM with an EMPTY auto-fix set — everything defaults ask-user; auto-fix rules accrete one-by-one later, each gated by "mechanically safe AND worth the interruption", triggering case attached. Rationale: co-presence (D5/D8) makes ask-user ~3s; risk 18 (silent unverified auto-edit) is the downside; matches accretion (D3b/D4).
q: qi1|decided|inferred|2026-08-03|Two classes only: auto-fix (mechanical, applied+recorded, never escalates) and ask-user (touches intent, escalates, blocks delivery). §2.3.1 [accepted]
q: qi2|decided|inferred|2026-08-03|Classification owned by lead/review-rubric.md — a rule lookup, never a hardcoded list in bin/. §2.3.1 [accepted]
q: qi3|decided|inferred|2026-08-03|Unclassifiable finding -> ask-user, fail closed. §2.3.1, §3.6 [accepted]
q: qi4|decided|inferred|2026-08-03|ask-user actions = approve/fix/skip; delivery stays closed until all resolved. §2.3.1; live in tl-gate.sh [accepted]
q: qi5|decided|inferred|2026-08-03|A tl: shortcut on a danger_path is ask-user, never auto-fixable. §3.13 [accepted]
q: qi6|decided|inferred|2026-08-03|Constraint: the classifier must not grow into "the review" — mechanical slop only (risk 17). [accepted]
q: q3|decided|owner|2026-08-03|Auto-fix verification/audit design DEFERRED by q1 — no auto-fix in v1, so nothing to verify until the first auto-fix rule is proposed.
q: q2|decided|owner|2026-08-03|Rubric keyed by EXACT finding rule-id (never a category — categories force prose-judgment, the on-ramp to risk 17). Entry shape: class + not-when (machine-read) + why-safe + hits (human/curation). No entry -> ask-user. v1 rubric has zero auto-fix entries.
q: q4|decided|owner|2026-08-03|E8.3 can't become the review by construction — classification is a pure 2-way ROUTER over detector-emitted rule-ids, never a detector. Guard here = router-not-detector + a why-safe certification on every auto-fix promotion (curate via hits + E6.6 prune). Broader risk-17 drift lives in the DETECTORS (E8.1 #53 /code-review, E8.2 #54 spec-diff) — flag there, not here.
q: q6|decided|owner|2026-08-03|Failure to avoid (v1): the classifier is DECORATIVE — empty rubric -> all ask-user -> approve-all -> indistinguishable from a rubber stamp (risk-26 shape). NOT risk-18 (auto-fix empty). Done: (1) rubric lookup on exact rule-id, not hardcoded; (2) unclassifiable->ask-user; (3) class_source provenance on every finding (rubric:<id> vs default:no-entry) so an empty rubric is legible; (4) review-rubric.md exists with entry shape + one inert commented example. Non-goals: no populated auto-fix set, no auto-fix apply/verify/audit (q3), no detector changes (#53/#54).
---
# Finding classification (auto-fix vs ask-user)

_Backlog:_ GitHub #55 (E8.3) · _Parent:_ Epic 8 (#9) · _Grill:_ E6.1 hand-run, 2026-08-03 · **specified**

## v1 scope (q1, decided)
Ship the **classification mechanism only, with an empty `auto-fix` set.** Every finding defaults to
`ask-user`. The rubric (`lead/review-rubric.md`) can promote a finding class to `auto-fix` one rule at
a time, later — each gated by "mechanically safe **and** worth the interruption," with the triggering
case attached (the §2.5 override→PR shape).

**Why:** co-presence (D5/D8) makes `ask-user` a ~3s terminal press, so auto-fix's upside is low now;
risk 18 (a mis-classified `ask-user` becomes a silent, unreviewed edit) is the real downside; and it
matches how the rest of `lead/` accretes (D3b/D4). Auto-fix verification/audit is deferred with it (q3).

## Settled by the corpus (inferred, accepted — see qi1–qi6)
Two classes; rubric-owned classification; unclassifiable → ask-user; approve/fix/skip; `tl:` on a
danger path is ask-user; the classifier is not the review.

## Definition of done (v1)
1. Findings classified by rubric lookup on **exact `rule`-id**, not a hardcoded list (q2).
2. Unclassifiable → `ask-user` (already live in `tl-gate.sh`).
3. **`class_source` provenance** on every finding (`rubric:<id>` vs `default:no-entry`) so an empty
   rubric is legible, not a rubber stamp (q6).
4. `review-rubric.md` exists with the entry **shape** + one **inert commented example** — first real
   auto-fix rule is a one-line add (q2).

## Non-goals (v1)
No populated auto-fix set; no auto-fix apply/verify/audit (q3, deferred); no detector changes — the
risk-17 drift guard belongs in the detectors (#53 `/code-review`, #54 spec-diff), not here (q4).
