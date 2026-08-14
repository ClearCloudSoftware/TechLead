---
id: tl-kickoff
backlog: kickoff
title: Greenfield kickoff / ideation
state: drafted
grilled_at: 2026-08-14
outcome:
q: q1|decided|owner|2026-08-14|Interview mechanism (REVISED from chat): a TERMINAL transcript-replay loop. tl-kickoff runs the interview from the shell — each turn is a discrete claude -p call (no LLM in the supervision loop), the running conversation lives in a transcript FILE (killable/reconstructable, §3.2; harness-agnostic vs claude session files, §5). No Claude Code app needed. The driver streams each turn (stream-json) so it's not a silent black box.
q: q2|decided|owner|2026-08-14|Outputs (Q2=b): CONTEXT.md (domain glossary) + seed backlog items. NOT AGENTS.md (layout of existing code — comes later via tl-scaffold-context once code exists).
q: q3|decided|owner|2026-08-14|Write vs propose (Q3=a): draft-then-approve. CONTEXT.md written uncommitted (owner reviews+commits); backlog items shown for confirmation before tl-backlog add persists them.
q: q4|decided|owner|2026-08-14|Relationship (Q4=a): greenfield path, complementary to tl-scaffold-context (brownfield/repo-derived). Chosen by project state: empty repo -> kickoff; existing -> scaffold-context.
q: q5|decided|owner|2026-08-14|New bash (Q5=a): a thin 'tl-kickoff <project>' reads the composed CONTEXT.md on stdin, refuses to overwrite, writes uncommitted, prints review/commit + seed-backlog next-steps. Backlog reuses tl-backlog add; no new adapter.
q: q6|decided|owner|2026-08-14|Backlog curation (Q6=a): the skill proposes the seed behaviours in chat, owner confirms which, skill runs tl-backlog add for each survivor. The chat is the review — no proposal file.
q: q7|decided|owner|2026-08-14|questions.md (Q7=a): OUT of scope. Kickoff produces CONTEXT.md + backlog only; questions.md seeding stays with grill propose-mode (#100).
q: q8|decided|owner|2026-08-14|Trigger (Q8=a): the skill OFFERS kickoff after tl-new on a fresh empty project; also invokable explicitly. Never forced.
q: q9|decided|owner|2026-08-14|Transcript file vs claude session files (owner): plain transcript file, owned by TechLead. Harness-agnostic (works with any claude -p-like adapter, incl. opencode) and single-owner (§3.1). Session files would tie kickoff to Claude Code and put state in an opaque store.
---
# Greenfield kickoff / ideation

_Backlog item:_ `kickoff`

tl-kickoff: greenfield project-ideation. The techlead skill interviews the owner in chat; tl-kickoff persists the composed CONTEXT.md + the skill seeds the backlog. Complements tl-scaffold-context (brownfield) and propose-mode (questions).
