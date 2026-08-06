# Vendored: Standards review brief — mattpocock-skills:code-review @ 1.2.0

**Source:** `mattpocock-skills:code-review` (claude-plugins-official plugin), pinned **v1.2.0**.
**Vendored per §3.14** — copied in-repo so an upstream bump arrives as a reviewable diff to this file,
not a silent change. Only the **Standards** axis is taken; TechLead's `tl-specdiff` owns the Spec axis.
The skill is instructions-only (it cannot run headless), so its Standards brief is embedded here for the
`claude-standards.sh` adapter to paste into a `claude -p` prompt.

Do **not** edit this file to encode local judgement. Local conventions live in the managed project's
`AGENTS.md` and this instance's `lead/review-rubric.md`, and they **override** the baseline below.

## The Standards brief

Review the change for whether the code conforms to this repo's **documented** coding standards. Inputs:
the diff, the repo's standards docs (`AGENTS.md` + `lead/review-rubric.md`), and the smell baseline below.

Report, per file/hunk:
- **standards-violation** — the diff breaks a rule the repo's docs actually state. Cite the file + rule.
  This is a *hard* finding: the repo wrote the rule down.
- **standards-smell** — the diff trips a baseline smell below. Name the smell, quote the hunk.
  **Always a judgement call**, never a hard violation.

Two binding rules: the repo's documented standard **overrides** this baseline, and every baseline smell
is a judgement call. Skip anything automated tooling already enforces.

## Smell baseline (Fowler, *Refactoring* ch.3) — applies even when the repo documents nothing

1. Mysterious Name  2. Duplicated Code  3. Feature Envy  4. Data Clumps  5. Primitive Obsession
6. Repeated Switches  7. Shotgun Surgery  8. Divergent Change  9. Speculative Generality
10. Message Chains  11. Middle Man  12. Refused Bequest
