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

  **Two-tier (owner decision 2026-08-14).** The bank is scoped in two layers: an **owner-global**
  bank at `TL_HOME/lead/questions.md` (priors that cross every project) and a **per-project** bank at
  `<project>/.techlead/lead/questions.md` (questions that don't leave that repo). A grill inside
  project X sees **both, concatenated global-first** (`global ++ X`) — not "nearest wins", which would
  shadow the global priors. Project banks stay isolated from each other; only the global tier travels.
  Seeding (#49) therefore fills the global tier from cross-cutting scars and each project tier from its
  own. *The merge is not built yet* — there are no managed projects to merge with (`data/projects/` is
  empty), so today's single-tier read is correct. When the first project grows a local question, the
  read becomes `global ++ project` and the `hits:` write splits back per tier by ordinal offset (a
  global entry firing in X bumps the global file, not X's). See the `# ponytail:` markers in
  `bin/tl-grill.sh` for the two exact sites.
- **`voice.md`** — prose, but still shaped: a short ladder of do/don't with examples, not adjectives.
- **`decisions/`** — one ADR per decision, following `decisions/TEMPLATE.md`. Ground truth for the
  grill's inference pass.

## The hit counter (E6.3 / D4)

Every rule and every question carries `hits: N  last: <date>`. Bump it when the rule fires during a
grill (an inferred answer it justified) or a review. Reuse-rate is the **early risk-1 signal**: a
stable core of rules that keep firing = judgment captured; a pile of once-used rules = a generic
engineer with a notebook (risk 2). Auto-bumped now: a grill bumps the `questions.md` entries it drew
answers from, and a review bumps the `review-rubric.md` rules its findings cited (the driver reports
which via a numbered ref; `bump_hits` in `tl-common.sh` is the single owner of the write). The reuse
count feeds the D13 kill-gate alongside `tl-metric` time.

## Consolidation (E6.6) — the promote-and-prune routine

`lead/` grows toward whatever broke most recently; left alone it overfits, and a pile of once-used
rules is a generic engineer with a notebook (risk 2), not captured judgment. Consolidation is the
habit that fights that. It is **owner-run — or run by an agent whose proposal the owner reviews —
never on a timer and never a silent rewrite.** An agent may *propose* cuts and merges; only the
owner commits them.

**Trigger (cadence, not a clock).** Run a pass when any of these fires:
- ~10 owner overrides have accrued since the last pass (`tl-metric outcome`), or
- a D13 kill-criterion checkpoint is due, or
- `AGENTS.md` or any single `lead/` file crosses the context-budget ceiling in `AGENTS.md` — a file
  over the line is due for a pass, not for more appending.

**Four tiers** — where a pass moves content, using files we already keep:
- **Raw** — individual override corrections and freshly captured questions, as they land.
- **Episodic** — the same, grouped by the task/theme that produced them (each rule's `<!-- born: … -->`
  trail already records that grouping).
- **Semantic** — the durable rule several raw entries imply, written into `principles.md` /
  `review-rubric.md`.
- **Procedural** — a question asked so often it becomes a standing check in `questions.md`.

**Every pass does three things — and deletion is the point:**
1. **Promote** raw entries that recur into one semantic rule (bump `hits`; add the reuse to its
   `born:` trail).
2. **Merge** duplicates — two rules saying one thing collapse to one; the weaker `hits` folds in.
3. **Delete** entries that no longer earn their place. After a handful of grills a rule still at
   `hits: 1` is a one-off, not a prior (junk-drawer defense, D4). An entry kept out of habit *is* the
   failure mode — cutting it is the work, not a loss.

**Brownfield-check every surviving prior (§2.4).** Minimalist priors — fewest files, shortest diff,
no unrequested abstractions — are strong greenfield advice and frequently *wrong* on brownfield,
where consistency with an existing verbose pattern beats local minimalism and a mature codebase's
conventions *are* abstractions someone requested years ago. Ask: does it still hold on a six-year-old
shared repo? If not, scope it with an intensity level.

## Adding a rule — the contradiction check (§2.6, the learning loop)

The loop appends a new prior on every owner override. Appending blindly lets two rules drift into
conflict, both live at once. So **before any `lead/` diff is proposed, the proposing agent first reads
the target file and compares the new rule against the ones already there** — a plain read-and-compare
against `principles.md` / `review-rubric.md` / `questions.md`, no similarity engine. When in doubt,
flag: a false positive costs the owner ten seconds; a missed contradiction costs a silent
inconsistency.

On a conflict, surface **both rules together** for the owner to reconcile exactly one way:
- **keep** — the existing rule stands; drop the new one.
- **merge** — fold both into one (union the ladders, widen the *Not when*).
- **supersede** — the new rule replaces the old, and **the superseded rule is removed, not left beside
  its replacement** — two rules with one dead is the drift this check exists to stop.

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
