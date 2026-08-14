#!/usr/bin/env bash
# tl-scaffold-test.sh — draft a test harness for a survey (greenfield / no-framework) project so it can
# graduate to `ready` (§2.7). The harness encodes the backlog's intended behaviours as failing tests —
# one failing-id per line, silent when all pass (the TechLead test contract). DRAFT-then-approve: it
# writes test.sh and sets test_command, then STOPS. What "done" means is the owner's call, so it never
# baselines/promotes for you, and never overwrites an existing test.sh.
#
# For an EXISTING repo with a known stack, tl-detect/tl-onboard already set test_command — you don't
# need this. This is for the greenfield case where there is no runner to detect.
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
name="${1:?usage: tl-scaffold-test <project>   (run from inside the project)}"
path="$("$BIN/tl-project.sh" get "$name" path)" || tl_die "unknown project: $name (run from inside it, or tl-onboard/tl-new it first)"
backlog="$path/.techlead/data/backlog.md"
[ -f "$backlog" ] || tl_die "no backlog at $backlog — add the behaviours first (one '## <slug>: <title>' per item)"
target="$path/test.sh"
[ -e "$target" ] && tl_die "$target already exists — edit it by hand (refusing to overwrite an existing harness)"

scaffolder="${TL_SCAFFOLD_TEST_CMD:-}"
if [ -z "$scaffolder" ]; then
  tl_die "no scaffolder configured (TL_SCAFFOLD_TEST_CMD; tl-init wires it for the claude harness). Draft $target
  by hand: a #!/bin/sh that runs the app and echoes one failing-id per unmet behaviour, silent when all pass."
fi

tl_log "scaffold-test: drafting a harness for '$name' from its backlog (calling scaffolder)…"
draft="$(TL_SCAFFOLD_NAME="$name" TL_SCAFFOLD_PROJECT="$path" TL_SCAFFOLD_BACKLOG="$backlog" $scaffolder || true)"
[ -n "$draft" ] || tl_die "scaffolder produced nothing — draft $target by hand (see the contract above)"
printf '%s\n' "$draft" > "$target"
chmod +x "$target"
"$BIN/tl-project.sh" set "$name" test_command "sh test.sh"

echo "tl: drafted $target  and set test_command='sh test.sh'."
echo "tl: REVIEW it — a test defines what 'done' means, which is yours to approve. Then, in order:"
echo "      \$EDITOR $target                       # tweak until it captures the behaviour you want"
echo "      git -C \"$path\" add test.sh && git -C \"$path\" commit -m 'add test harness'"
echo "      tl-baseline $name                       # records known-failing set → promotes survey to ready"
echo "tl: (commit before baselining — workers branch from HEAD and won't see an uncommitted harness.)"
