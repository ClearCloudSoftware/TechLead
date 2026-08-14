#!/usr/bin/env bash
# classify-smoke.sh — Epic 8 (#55). tl-classify is a pure router over exact rule-ids: unknown and
# commented-out entries fail closed to ask-user/default:no-entry; an active entry returns its class
# with rubric:<id> provenance; the shipped rubric shell classifies nothing (empty auto-fix set).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
trap 'rm -rf "$WORK"' EXIT
DEFAULT="$(printf 'ask-user\tdefault:no-entry')"

echo "== unknown rule -> ask-user / default:no-entry (fail closed) =="
[ "$(TL_REVIEW_RUBRIC=/dev/null "$BIN/tl-classify.sh" some-rule)" = "$DEFAULT" ] \
  || fail "unknown rule not fail-closed"

echo "== active entry -> its class + rubric:<id> =="
R="$WORK/rubric.md"
printf '### trailing-ws\nclass: auto-fix\n### danger-touch\nclass: ask-user\n' > "$R"
[ "$(TL_REVIEW_RUBRIC="$R" "$BIN/tl-classify.sh" trailing-ws)"  = "$(printf 'auto-fix\trubric:trailing-ws')" ]  || fail "auto-fix entry not matched"
[ "$(TL_REVIEW_RUBRIC="$R" "$BIN/tl-classify.sh" danger-touch)" = "$(printf 'ask-user\trubric:danger-touch')" ] || fail "ask-user entry not matched"

echo "== commented example is inert =="
printf '<!--\n### trailing-ws\nclass: auto-fix\n-->\n' > "$R"
[ "$(TL_REVIEW_RUBRIC="$R" "$BIN/tl-classify.sh" trailing-ws)" = "$DEFAULT" ] || fail "commented entry was not inert"

echo "== shipped rubric shell has an empty auto-fix set =="
[ "$("$BIN/tl-classify.sh" danger-path)" = "$DEFAULT" ] || fail "shipped rubric is not empty-by-design"

echo "PASS: classifier routes by exact rule-id; unknown + commented -> ask-user/default:no-entry"
