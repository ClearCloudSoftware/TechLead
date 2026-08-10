#!/usr/bin/env bash
# vendor-smoke.sh — Epic 7 (#50). The five judgment skills are vendored as pinned reference copies with
# provenance headers, each filename carries its pin, and the manifest flags the code-review drift.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; V="$REPO/.agents/skills"
fail() { echo "FAIL: $1"; exit 1; }

for name in grilling to-tickets domain-modeling codebase-design implement; do
  f="$V/$name@1.2.3.md"
  [ -f "$f" ] || fail "missing vendored skill: $name@1.2.3"
  grep -q 'Vendored (pinned reference)' "$f" || fail "$name: no provenance header"
  grep -q 'not wired into any adapter' "$f"   || fail "$name: header does not state it's reference-only"
  grep -q 'upstream SKILL.md (verbatim)' "$f"  || fail "$name: no verbatim-upstream marker"
done

[ -f "$V/VENDORED.md" ] || fail "no VENDORED.md manifest"
grep -q 'code-review-standards' "$V/VENDORED.md" || fail "manifest omits the code-review drift entry"
grep -qi 'drift' "$V/VENDORED.md"                || fail "manifest does not flag the 1.2.0 drift"

echo "PASS: 5 judgment skills vendored + pinned with provenance; manifest flags the code-review drift"
