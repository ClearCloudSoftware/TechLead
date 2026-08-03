---
id: tl-project-context
backlog: e9.2
title: CONTEXT.md + project AGENTS.md (survey deliverables)
state: specified
grilled_at: 2026-08-03
outcome:
q: q1|decided|owner|2026-08-03|Every glossary entry carries confidence + source: FOUND (cite file:line, trusted) vs GUESSED (inferred from usage, flagged provisional, never stated as fact). Stops the survey laundering a guess into a fact ("wrong glossary worse than none", risk 21). [reuse of principles rule "Make emptiness legible" -> hits 4]
q: qi1|decided|inferred|2026-08-03|Two committed files — AGENTS.md (layout, current+deprecated conventions, test commands, danger zones) + CONTEXT.md (vocabulary: domain glossary + jargon). §2.7 [accepted]
q: qi2|decided|inferred|2026-08-03|Both are survey deliverables — onboarding = plan/survey tasks producing them; no new machinery. §2.7 [accepted]
q: qi3|decided|inferred|2026-08-03|Owner-only, zero blast radius (a document; no code changes). Safest tier. §2.7/§2.2 [accepted]
q: qi4|decided|inferred|2026-08-03|Committed IN the managed project — survive TechLead, help human teammates. §2.7 [accepted]
q: qi5|decided|inferred|2026-08-03|First CONTEXT.md is owner-reviewed before it's trusted. §8.21/risk 21 [accepted]
q: q2|decided|owner|2026-08-03|Unreviewed CONTEXT.md = UNTRUSTED: produced in draft, doesn't feed worker briefs until the owner signs off (fail closed — an unverified glossary is the "worse than none" case). First pass reviews the whole file; after that only NEW Guessed entries need the owner (Found entries are cited/self-verifying). Soft rule-1 touch (save owner attention for the uncertain bits); primarily the fail-closed default.
q: q3|decided|owner|2026-08-03|Split by WORD-vs-PRACTICE: vocabulary -> CONTEXT.md, layout/practice/danger -> AGENTS.md; deprecated items file by type (deprecated term -> CONTEXT, deprecated convention -> AGENTS). Rot (risk 13) DEFERRED for v1 (bootstrap repo known cold; don't pre-build a refresh trigger) — tracked as #73 (Epic 10 / #11). Revisit when a 2nd brownfield repo is added (readiness-ladder trigger).
q: q4|decided|owner|2026-08-03|Failure to avoid (beyond confident-wrong, handled by q1): VOLUME as noise — a 200-entry glossary of obvious terms (user, id, handler) buries the 10 that matter and you stop trusting it. Guard: HIGH BAR for entry — only non-obvious, domain-specific, paragraph-replacing terms; if a competent dev already knows it, it's not glossary-worthy. Done: two files produced; every term Found(cited)/Guessed(flagged) (q1); high-bar entries; unreviewed=untrusted, first fully reviewed then only new guesses (q2); word-vs-practice split (q3). Non-goals: no rot/refresh (deferred #73); nothing beyond the committed files.
---
# CONTEXT.md + project AGENTS.md (survey deliverables)

_Backlog:_ GitHub #60 (E9.2) · _Parent:_ Epic 9 (#10) · _Grill:_ E6.1 grill #4, 2026-08-03 · **specified**

The highest-value work on the safest tier (§2.7): a committed `AGENTS.md` (layout/conventions/danger)
+ `CONTEXT.md` (the project's vocabulary), produced by survey `plan` tasks. Matters most on brownfield.

## Definition of done (v1)
1. `CONTEXT.md` (glossary) + `AGENTS.md` (layout/conventions/danger) produced by the survey.
2. Every glossary term is **Found** (cited `file:line`) or **Guessed** (flagged provisional) — never a bare fact (q1).
3. **High bar** for entries — only non-obvious, domain-specific, paragraph-replacing terms (q4).
4. **Unreviewed = untrusted:** first pass fully owner-reviewed, then only new Guessed entries (q2).
5. **Word-vs-practice split** — vocabulary → CONTEXT, layout/practice/danger → AGENTS (q3).

## Non-goals (v1)
No rot/refresh mechanism (deferred → #73); nothing beyond the committed files (teammates just read
them; no sharing machinery).
