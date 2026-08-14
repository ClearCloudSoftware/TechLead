#!/usr/bin/env bash
# tl-classify.sh — the finding classifier (§2.3.1, E8.3 / #55). A pure 2-way ROUTER over
# detector-emitted rule-ids: it maps a finding's exact `rule` to a class via lead/review-rubric.md and
# nothing else. It never inspects the finding's content — that would make it a detector, the on-ramp to
# risk 17 (q4/qi6). Unknown rule-id -> ask-user, fail closed (qi3, §3.6). v1's rubric has an EMPTY
# auto-fix set, so every finding classifies ask-user; the class_source (`rubric:<id>` vs
# `default:no-entry`) keeps that emptiness legible rather than a rubber stamp (q6).
#
# Output: one line `class<TAB>class_source` on stdout.  Single owner of classification (§3.1).
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
rule="${1:?usage: tl-classify <rule-id>}"
rubric="${TL_REVIEW_RUBRIC:-$TL_LEAD/review-rubric.md}"   # overridable for tests, single owner
TAB="$(printf '\t')"

# An ACTIVE entry is a `### <exact-rule-id>` heading followed by a `class:` line. Commented-out
# examples (<!-- ... -->) are inert and skipped, so the shipped shell classifies nothing.
class=""
[ -f "$rubric" ] && class="$(awk -v want="$rule" '
  { if (skip) { if ($0 ~ /-->/) skip=0; next }
    if ($0 ~ /<!--/) { if ($0 !~ /-->/) skip=1; next } }
  /^###[ \t]+/ { cur=$0; sub(/^###[ \t]+/,"",cur); sub(/[ \t]+$/,"",cur); next }
  /^class:[ \t]*/ { if (cur==want) { v=$0; sub(/^class:[ \t]*/,"",v); sub(/[ \t]+$/,"",v); print v; exit } }
' "$rubric")"

case "$class" in
  auto-fix|ask-user) printf '%s%srubric:%s\n' "$class" "$TAB" "$rule" ;;
  *)                 printf 'ask-user%sdefault:no-entry\n' "$TAB" ;;   # fail closed (qi3)
esac
