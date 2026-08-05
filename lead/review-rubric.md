# review-rubric.md — the block/nit ladder (§2.3.1, §3.13, E8.3)

**Empty by design.** This file classifies review/gate findings into two classes. Until a grill
produces a real rule it has **zero active entries**, so every finding falls through to `ask-user`
(fail closed). Never seed it from someone else's rubric — see [SHAPE.md](SHAPE.md)'s cardinal rule.
Entries accrete one at a time from real findings, each with its triggering case attached (§2.5).

## What reads this file

`bin/tl-classify.sh` is the single owner (§3.1). Given a finding's **exact** `rule`-id it returns a
`class` + `class_source`. The classifier is a pure ROUTER over rule-ids — it never inspects finding
content (that would make it a detector; risk 17). An unknown rule-id → `ask-user` / `default:no-entry`.

## Two classes (q1, qi1)

- `auto-fix` — mechanical, safe to apply and record without asking; never escalates. **v1 has none.**
- `ask-user` — touches intent; escalates; blocks delivery until resolved (approve / fix / skip). The default.

## Entry shape (q2)

Keyed by the **exact** finding `rule`-id — never a category (categories force prose-judgment, the
on-ramp to risk 17). `class` is machine-read by the classifier; `not-when` / `why-safe` / `hits` are
for human curation and the future auto-fix apply step (deferred, q3). Promoting a finding to
`auto-fix` requires a `why-safe` certification; a `tl:` shortcut on a `danger_path` is always
`ask-user`, never auto-fixable (qi5).

    ### <exact-rule-id>
    class: auto-fix                 # or ask-user
    not-when: <condition under which this rule must NOT auto-fix>
    why-safe: <one line certifying mechanical safety — required to promote to auto-fix>
    hits: 0   last: —               # bump when this entry classifies a real finding (E6.3)

## Inert example — commented, NOT an active rule

<!--
### trailing-whitespace
class: auto-fix
not-when: path matches a danger_path glob
why-safe: whitespace-only edit, no semantic change, re-runnable
hits: 0   last: —
-->
