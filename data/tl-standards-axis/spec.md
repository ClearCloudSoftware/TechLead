---
id: tl-standards-axis
backlog: e8.1
title: Standards axis (vendor /code-review)
state: specified
grilled_at: 2026-08-06
outcome:
q: q1|decided|owner|2026-08-06|Take ONLY the Standards axis from /code-review; tl-specdiff owns Spec (the differentiator). The external Spec half is never run.
q: q2|decided|owner|2026-08-06|Standards NEVER blocks — draft-only advice. Blocking surface stays intent (Spec axis) + mechanical detectors (regression/scope/danger).
q: q3|decided|owner|2026-08-06|Sources: project AGENTS.md (canonical standards doc, §2.7) + lead/review-rubric.md, with the vendored 12-smell baseline underneath. CODING_STANDARDS/CONTRIBUTING fold-in dropped for v1.
q: q4|decided|owner|2026-08-06|VENDOR the Standards brief (mattpocock code-review's 12-smell Fowler baseline + its two rules), pinned to plugin v1.2.0; the adapter pastes it, upstream bumps = reviewable diffs (§3.14). Pure subscribe impossible — the skill is instructions-only, cannot run headless.
q: q5|decided|owner|2026-08-06|Runs in the review kind ONLY, not on every change delivery — Standards is a deliberate review, not a merge tax. Promote to every-change later if wanted (cheap direction).
q: q6|decided|owner|2026-08-06|Emits STRUCTURED findings, two rule-ids: standards-violation (broke a documented convention — hard) and standards-smell (Fowler baseline — always a judgement call). Carries the file/hunk. Draft-only, so never routed to the blocking gate.
q: qi1|decided|inferred|2026-08-06|Source = mattpocock-skills:code-review@1.2.0, Standards brief only; vendored to .agents/skills/code-review-standards@1.2.0.md (version in filename so a bump is an obvious diff).
q: qi2|decided|inferred|2026-08-06|#53 ships the axis as a standalone callable (tl-standards.sh + adapters/claude-standards.sh + vendored brief + report renderer); #58 review kind composes it with tl-specdiff — that structure is already grilled (spec-diff qi1/qi5).
---
# Standards axis (vendor /code-review)

_Backlog item:_ `e8.1`

