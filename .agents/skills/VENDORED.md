# Vendored skills — pinned reference copies (§3.14, E7.3/#50)

Judgment-encoding skills, copied in-repo and pinned so an upstream change arrives as a **reviewable
diff** rather than silently. These are reference copies for provenance — they are **not** wired into
any adapter; TechLead's grill/worker/review adapters carry their own prompts. Local judgement never
lives here — it lives in `lead/`.

| Skill | Pinned | Source |
|---|---|---|
| grilling | 1.2.3 | mattpocock-skills:grilling |
| to-tickets | 1.2.3 | mattpocock-skills:to-tickets |
| domain-modeling | 1.2.3 | mattpocock-skills:domain-modeling |
| codebase-design | 1.2.3 | mattpocock-skills:codebase-design |
| implement | 1.2.3 | mattpocock-skills:implement |
| code-review-standards | **1.2.0** | mattpocock-skills:code-review (Standards axis, #53) |

## Drift to review
`code-review-standards` is pinned at **1.2.0** (adopted in #53); mattpocock-skills is now at **1.2.3**.
Bumping it changes live Standards-axis behaviour, so it is a **separate reviewable diff**, not folded
into #50. To bump: re-vendor from 1.2.3 and review the diff against `code-review-standards@1.2.0.md`.

## Re-vendoring (when you choose to bump)
Copy the upstream `SKILL.md` verbatim under the provenance header, rename the file to the new version,
and review the diff. The pin is the filename version suffix.
