---
id: tl-grill-propose
backlog: grill-propose
title: Grill propose-mode (bootstrap the question bank)
state: drafted
grilled_at: 2026-08-14
outcome:
q: q1|decided|owner|2026-08-14|Trigger (Q1=d): auto-fire propose-mode when a grill yields 0 questions, AND an explicit force path for any item.
q: q2|decided|owner|2026-08-14|Propose-not-write (Q2=yes): reuse tl-propose -> data/proposals/; nothing enters lead/ without an owner promote. Same pattern as override/escalation loops.
q: q3|decided|owner|2026-08-14|Curation (Q3=a): draft all candidates to ONE file; owner deletes unwanted lines in place; one promote command appends the survivors.
q: q4|decided|owner|2026-08-14|Immediacy (Q4=a): two-step. promote seeds the bank; the ORDINARY grill then runs this item unchanged. Propose only primes the pump; #99 guard stays intact until real questions exist.
q: q5|decided|owner|2026-08-14|One file, N candidates (Q5=yes): data/proposals/question-<slug>.md holds several candidates, pruned in place (not N separate files).
q: q6|decided|owner|2026-08-14|Proposer inputs (Q6=both): the LLM sees the backlog item PLUS the existing bank + decisions/ (same corpus the inference pass reads) so candidates complement, not duplicate, and mirror the owner's phrasing.
q: q7|decided|owner|2026-08-14|Promote (Q7=yes): 'tl-grill promote <slug>' reads the pruned file, appends each survivor to lead/questions.md in SHAPE format (### question / hits: 0 last: — / _scar:_), then archives the proposal.
q: q8|decided|owner|2026-08-14|Scar (Q8=a): proposed questions promote as provisional — _scar:_ (proposed — unproven), hits: 0. The junk-drawer defense (D4: hits:1=one-off) prunes ones that never fire. Owner may hand-write a real scar later. No hard gate.
q: q9|decided|owner|2026-08-14|tl-run integration (Q9=yes): on 0 questions, auto-draft the candidate file (idempotent — tl-propose skips if it exists, so re-runs don't re-spend), then STOP pointing at the file + 'tl-grill promote <slug>'. If no proposer is configured, degrade to the plain seed-questions.md (#99) message.
q: q10|decided|owner|2026-08-14|Explicit invocation (Q10=yes): 'tl-grill propose <slug>' drafts candidates for an item regardless of bank state; mirrors tl-grill answer/reject/promote.
q: q11|decided|owner|2026-08-14|Proposer adapter (Q11=a): NEW adapters/claude-grill-propose.sh (prompt: propose N item-derived questions complementing the bank, each provisional), drafting via tl-propose's shared file machinery. claude-propose.sh stays focused on single override/escalation candidates.
---
# Grill propose-mode (bootstrap the question bank)

_Backlog item:_ `grill-propose`

Grill propose-mode: on a thin/empty lead/questions.md the grill drafts candidate questions from the backlog item; owner curates + promotes into the bank. Keeps judgment owner-owned; solves the cold-start (#49) behind the empty-bank dispatch guard (#99).
