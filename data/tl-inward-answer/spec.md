---
id: tl-inward-answer
backlog: e9.1
title: Inward answer kind (retrieval over the owner's own record)
state: specified
grilled_at: 2026-08-03
outcome:
q: q1|decided|owner|2026-08-03|Every answer CITES its source (decision/spec/line); "I don't know / no basis in your notes" is a first-class answer, never a manufactured guess. Confident-wrong is the one failure (worse than no answer, even on your own notes). [reuse of principles rule "Make emptiness legible" -> hits 3]
q: qi1|decided|inferred|2026-08-03|Inward only — answers the owner, never teammates; outward answer stays cut (D7). §7.2 [accepted]
q: qi2|decided|inferred|2026-08-03|Answers the owner's own questions (why X / state of Y / what we decided about Z) from the written record. #59/§7.2 [accepted]
q: qi3|decided|inferred|2026-08-03|Retrieves over lead/decisions/ + project CONTEXT.md, plus the grill specs + principles (the written corpus). #59 [accepted]
q: qi4|decided|inferred|2026-08-03|Zero blast radius — reads notes back to the owner; no merges, no code, no other audience. §7.2/D7 [accepted]
q: qi5|decided|inferred|2026-08-03|No bot-badge / draft-approve-send machinery — that was the OUTWARD trust cost (cut). Inward answers the owner directly. §2.2 (that row is the outward version) [accepted]
q: q2|decided|owner|2026-08-03|Lightweight QUERY, not a full task kind: no worktree/branch/teardown (those isolate code changes; there are none). Take a question -> retrieve relevant notes -> answer with citations (or "I don't know"). Add machinery (background/long-running) only if it bites. [clean reuse of "Let it ask, don't pre-automate" (YAGNI form), post-sharpening -> hits 2]
q: q3|decided|owner|2026-08-03|Corpus = lead/decisions/ (ADRs) + data/*/spec.md (grill specs) + project CONTEXT.md + lead/principles.md. NOT briefs (disposable/how), raw backlog (ungrilled), or state/ (volatile) — throwaway or not-yet-decisions. The corpus is also the citation source (q1).
q: q4|decided|owner|2026-08-03|Failure to avoid (beyond confident-wrong, handled by q1): presenting a STALE/superseded decision as current — a real citation on an overturned decision is confident-wrong that looks legit. The answer respects ADR Status (superseded/accepted) and flags age. Done: cite per claim + "I don't know" (q1); query not kind (q2); flags stale/superseded instead of quoting as live; owner-only. Non-goals: no outward answering, no draft-send-badge, plain search first (no pre-built embeddings unless it visibly misses).
---
# Inward answer kind (retrieval over the owner's own record)

_Backlog:_ GitHub #59 (E9.1) · _Parent:_ Epic 9 (#10) · _Grill:_ E6.1 grill #3, 2026-08-03 · **specified**

Answers the owner's own questions from his own written record. Zero blast radius (D7/§7.2): the
trust-risky half — speaking *as* the owner *to* teammates — stays cut.

## Definition of done (v1)
1. Answers from the corpus (q3) with a **citation per claim**, and says **"I don't know"** when
   nothing solid (q1).
2. It's a **lightweight query**, not a task kind — no worktree/branch/teardown (q2).
3. **Flags stale/superseded sources** (respects ADR `Status`) instead of quoting them as live (q4).
4. **Owner-only** — never posts to anyone else.

## Non-goals (v1)
No outward/teammate answering; no draft-send-badge machinery (that was the outward trust cost, cut);
plain search over the corpus first — no pre-built embeddings unless plain search visibly misses.
