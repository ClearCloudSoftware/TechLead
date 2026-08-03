# principles.md — architecture priors

Owner-authored, accreted from real grills. Every rule follows [SHAPE.md](SHAPE.md) (ladder · not-when ·
intensity · persistence · `hits`). Do not import anyone else's priors — see `README.md`.

---

### Let it ask, don't pre-automate
hits: 2   last: 2026-08-03   <!-- born: E8.3 empty auto-fix; sharpened #2 (override); reused E9.1 lightweight-query-not-a-full-kind (#3) -->
**Ladder:** 1. Is the human present when this would fire? → if no, stop (this rule doesn't apply).
2. Is answering it cheap for them (seconds, one click)? → if yes, ship the mechanism **empty**: every
case escalates. 3. Let entries earn their way into automation one at a time, each with the triggering
case attached. 4. Pre-build the automation only when co-presence ends or the ask gets expensive.
**Not when:** the action loses data or is irreversible even once — then design the guard up front, don't
wait for a scar. Also off when the human isn't there (batch / overnight work). **A gate that stops and
*asks* is NOT the pre-automation this guards against** — under co-presence it's the right default, not
over-building (sharpened by owner override, E8.2 grill #2: the Spec check blocks every change).
**Intensity:** off | default (empty-first, accrete) | strict (empty-first *and* require a logged
triggering case before any entry is added).
**Persists:** every response; applies when uncertain; off only by the owner.

---

### Router, not detector
hits: 1   last: 2026-08-03   <!-- born: E8.3 grill — the classifier can't become the review -->
**Ladder:** 1. Could this component grow into the bigger thing it feeds? → if no, stop. 2. Can it be
built to only *route/forward*, never *originate*? → if yes, do that — give it a fixed input vocabulary
it cannot extend. 3. Push the origination/judgment up to the layer that owns it.
**Not when:** the component genuinely must originate — then it *is* that layer; name it and guard it
there, don't pretend it's a router. Over-applied, it fragments one responsibility across too many hops.
**Intensity:** off | default (prefer routing, push origination up) | strict (the input vocabulary must
be owned by another layer the router can't edit).
**Persists:** every response; applies when uncertain; off only by the owner.

---

### Make emptiness legible
hits: 4   last: 2026-08-03   <!-- born: E8.3 class_source; reused: E8.2 coverage (#2), E9.1 "I don't know" (#3), E9.2 glossary found-vs-guessed (#4) -->
**Ladder:** 1. Can this mechanism be a no-op (empty config, default path)? → if no, stop. 2. Can you
tell "working" from "doing nothing" at a glance? → if yes, stop. 3. If not, add provenance — record
*why* it took the path it did — so the no-op state is visible. 4. Never let a mechanism that can be
decorative hide that it is.
**Not when:** the mechanism can never be a no-op, or provenance costs more than it's worth (hot paths).
**Intensity:** off | default (add provenance where cheap) | strict (no ship until the no-op state is
observable).
**Persists:** every response; applies when uncertain; off only by the owner.
