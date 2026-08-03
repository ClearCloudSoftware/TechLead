# lead/ — the judgment layer (Phase 0)

This is the actual product; everything in `bin/` is transport.

The **shape** is now defined ([SHAPE.md](SHAPE.md)); the **content is not, by design.** Rules
**accrete from real feature grills** (backlog Epic 6), each carrying a per-rule `hits:` counter so the
layer can be told apart from a junk drawer (D4). Do **not** seed this from someone else's principles —
importing another person's judgment is the one failure this project exists to avoid (§2.4, §5).

Files (§2.4). Two exist now because the grill mechanics read them; the rest are born on their first
rule (see [SHAPE.md](SHAPE.md) for why, and for the required shape of each):

- `questions.md` — the grill question bank *(exists, near-empty)*
- `decisions/` — ADR log; `decisions/TEMPLATE.md` is the format *(exists)*
- `principles.md`, `review-rubric.md`, `delegation.md`, `escalation.md`, `voice.md` — born on first rule
