# lead/ — required shape (the asset)

This file specifies **shape, not content.** The content of `lead/` is the owner's judgment and
accretes drop-by-drop from real feature grills (§2.6, D2/D3b). Nothing here encodes a prior; it
defines the form a prior must take so that when one lands it is *executable* rather than a slogan.

> **Cardinal rule (§2.4, §5).** Never seed `lead/` from someone else's principles — not a generic
> senior engineer's, not this document's author's. Importing another person's judgment is the one
> failure the whole project exists to avoid. Files here are **empty by design** until a grill
> produces a rule. The shape below is adapted from [ponytail]; its *structure* is borrowed, its
> *content* is deliberately not.

## The files and when they exist

| File | Holds | Born |
|---|---|---|
| `principles.md` | architecture priors: what's premature, what's load-bearing | on its first rule |
| `review-rubric.md` | the block/nit ladder — what stops a PR vs. what's a comment | on its first rule |
| `delegation.md` | how work is split; what is never delegated | on its first rule |
| `escalation.md` | what reaches the owner, ask format, default-action rule, caps | on its first rule |
| `questions.md` | the grill question bank — *the owner's* questions (§2.6) | **now** (grill input) |
| `voice.md` | how notes and docs are written | on its first rule |
| `decisions/` | ADR log — ground truth for "why is it like this" | **now** (`decisions/TEMPLATE.md`) |

"Born on its first rule" is deliberate (D3/D4): pre-creating six empty files is the junk-drawer risk
inverted. The **shape is fixed up front here**; the *file* appears when it has content. Only the two
the grill mechanics read (`questions.md`, `decisions/`) exist from day one.

## Required shape for a prior-encoding file (§2.4)

`principles.md`, `review-rubric.md`, `delegation.md`, `escalation.md`. Each rule has four parts —
a list of values produces nothing; an agent cannot execute "prefer simplicity":

1. **A ladder with stop conditions.** A decision procedure, not a disposition. "Stop at the first
   rung that holds" is executable; "prefer the simple thing" is not.
2. **An explicit non-application list.** Where the rule must *not* be used. A principle with no
   stated exceptions gets over-applied, and confident over-application is worse than no principle.
3. **Intensity levels.** The same prior dialled up or down, selectable per project. Right for a
   greenfield service is often wrong for a shared legacy one.
4. **Persistence semantics.** States that it applies to every response, applies when uncertain, and
   names the only way to turn it off (adherence decays over a long session — §3.5).

### Rule template (format, not a real prior)

```
### <rule name>
hits: 0   last: —          # per-rule reuse counter (E6.3/D4) — bump when the rule fires in a grill
**Ladder:**  1. <stop condition>  2. <next rung>  3. <fallback>
**Not when:** <where this rule must not apply>
**Intensity:** off | default | strict — <what changes at each>
**Persists:** every response; applies when uncertain; off only by <owner override>.
```

## Shape of the other files

- **`questions.md`** — a flat list of the owner's questions, each traceable to a real scar (§2.6:
  "the question bank is the asset, not the answers"). One question per line/heading, same `hits:`
  counter. The grill's inference pass reads this file; a worker escalation that should've been asked
  at spec time gets added here (§2.5 second loop).
- **`voice.md`** — prose, but still shaped: a short ladder of do/don't with examples, not adjectives.
- **`decisions/`** — one ADR per decision, following `decisions/TEMPLATE.md`. Ground truth for the
  grill's inference pass.

## The hit counter (E6.3 / D4)

Every rule and every question carries `hits: N  last: <date>`. Bump it when the rule fires during a
grill (an inferred answer it justified) or a review. Reuse-rate is the **early risk-1 signal**: a
stable core of rules that keep firing = judgment captured; a pile of once-used rules = a generic
engineer with a notebook (risk 2). Kept by hand for now (code-free track); the reuse count feeds the
D13 kill-gate alongside `tl-metric` time. No script until there are rules to count — YAGNI.

## Curation (E6.6)

- **Prune low-reuse rules.** After a handful of grills, a rule still at `hits: 1` is a one-off, not a
  prior. Cut it. This is the junk-drawer defense accretion demands (D4). Owner-run; no cadence is
  fixed yet (open question §8.2).
- **Brownfield-check every new prior before it ships (§2.4).** Minimalist priors — fewest files,
  shortest diff, no unrequested abstractions — are strong greenfield advice and frequently *wrong*
  on brownfield, where consistency with an existing verbose pattern beats local minimalism and a
  mature codebase's conventions *are* abstractions someone requested years ago. Before a prior lands,
  ask: does it still hold on a six-year-old shared repo? If not, scope it with an intensity level.

## Outcome data (E6.4 / E6.5)

Two hand-fed signals, both cheap, both feeding risk-1 (§8.1):

- **Inferred-answer outcomes** — each grill, every inferred answer the owner *accepts* is evidence
  the layer works; every one they *correct* is a labeled override (§2.6). Corrections are logged
  automatically by `tl-grill answer`; read the per-grill tally with `tl-metric outcome`.
- **Spec outcomes** — when a shipped feature reverts or gets hotfixed, fill the spec's `outcome:`
  field by hand, citing the `q#` that missed it (D11): `tl-spec set <id> outcome "q3 missed the
  auth edge case — reverted"`. Scars are what make a senior; this is the lite version of full
  incident tracking (§7.1), deferred.

[ponytail]: https://github.com/DietrichGebert/ponytail
