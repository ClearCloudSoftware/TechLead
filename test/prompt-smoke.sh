#!/usr/bin/env bash
# prompt-smoke.sh — the interactive prompt helpers (tl-wizard) and the one command built on them
# (tl-grill prune). No tty here, so the two paths that a terminal would exercise are forced by
# stubbing tl_noninteractive — what's under test is the answer PARSING, not whether isatty works.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$REPO/bin"
fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"
export TL_CONFIG=          # hermetic: ignore any config/instance.env in this checkout
export TL_HOME="$REPO" TL_DATA="$WORK/data" TL_STATE="$WORK/state" TL_WORKTREES="$WORK/state/wt"
cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT
mkdir -p "$TL_DATA"

. "$BIN/tl-common.sh"; . "$BIN/tl-wizard.sh"

echo "== colour is off when stdout is not a tty =="
[ -z "$TL_C_STOP" ] || fail "colour leaked into non-tty output"
                                         # $0 here is not a tl-* script, so the prefix falls back to "tl"
[ "$(tl_stop "x")" = "tl: STOP — x" ] || fail "tl_stop plain form: $(tl_stop x)"
[ "$(tl_kv fix "do the thing")" = "  fix:    do the thing" ] || fail "tl_kv plain form: '$(tl_kv fix "do the thing")'"

echo "== non-interactive takes the stated default =="
[ "$(tl_text K "prompt" "the default")" = "the default" ] || fail "tl_text default"
[ "$(tl_pick_many K "prompt" a b c | tr '\n' ',')" = "a,b,c," ] || fail "tl_pick_many keeps all by default"

echo "== TL_ANSWER_<KEY> overrides, interactive or not =="
[ "$(TL_ANSWER_K=typed tl_text K "prompt" "the default")" = typed ] || fail "tl_text override"
[ "$(TL_ANSWER_K='a;c' tl_pick_many K "prompt" a b c | tr '\n' ',')" = "a,c," ] || fail "tl_pick_many override"

echo "== forced-interactive, no picker installed: answers are parsed =="
tl_noninteractive() { return 1; }        # stub: pretend stdin is a terminal
REAL_PATH="$PATH"; PATH=/usr/bin:/bin    # and pretend gum/fzf are absent — this is the fallback path

[ "$(echo hello | tl_text K "prompt" "the default" 2>/dev/null)" = hello ] || fail "tl_text reads the typed line"
[ "$(echo '' | tl_text K "prompt" "the default" 2>/dev/null)" = "the default" ] || fail "tl_text empty keeps the default"

got="$(echo '1 3' | tl_pick_many K "prompt" a b c 2>/dev/null | tr '\n' ',')"
[ "$got" = "a,c," ] || fail "tl_pick_many by number: $got"
got="$(echo '' | tl_pick_many K "prompt" a b c 2>/dev/null | tr '\n' ',')"
[ "$got" = "a,b,c," ] || fail "tl_pick_many empty keeps all: $got"
got="$(echo '9 zz 2' | tl_pick_many K "prompt" a b c 2>/dev/null | tr '\n' ',')"
[ "$got" = "b," ] || fail "tl_pick_many ignores junk and out-of-range: $got"
got="$(echo 2 | tl_choose K "prompt" a a b c 2>/dev/null)"
[ "$got" = b ] || fail "tl_choose by number: $got"

echo "== tl-grill prune rewrites the proposal, keeping only the picks =="
mkdir -p "$TL_DATA/proposals"
cat > "$TL_DATA/proposals/question-rotate-creds.md" <<'EOF'
# Candidate question — for your review (NOT yet in lead/)

preamble line that must survive

## Triggering case

backlog item 'rotate-creds'

## Drafted candidate (lead/questions.md)

### What is the rollback path?
body of the first question

### How do we page someone?
body of the second question

### What does done mean?
body of the third question
EOF

TL_ANSWER_GRILL_PRUNE_ROTATE_CREDS='What is the rollback path?;What does done mean?' \
  "$BIN/tl-grill.sh" prune rotate-creds >/dev/null
prop="$TL_DATA/proposals/question-rotate-creds.md"
n="$(grep -c '^### ' "$prop")"
[ "$n" -eq 2 ] || fail "expected 2 surviving candidates, got $n"
grep -q '^### What is the rollback path?' "$prop" || fail "kept candidate was dropped"
grep -q '^### What does done mean?' "$prop" || fail "kept candidate was dropped"
grep -q 'How do we page someone' "$prop" && fail "dropped candidate survived"
grep -q 'body of the second question' "$prop" && fail "dropped candidate's body survived"
grep -q 'body of the first question' "$prop" || fail "kept candidate's body was dropped"
grep -q 'preamble line that must survive' "$prop" || fail "file preamble was dropped"
grep -q '^## Triggering case' "$prop" || fail "'## ' section heading was dropped"

echo "== promote then takes exactly the survivors =="
export TL_LEAD="$WORK/lead"; mkdir -p "$TL_LEAD"
"$BIN/tl-grill.sh" promote rotate-creds >/dev/null 2>&1
n="$(grep -c '^### ' "$TL_LEAD/questions.md")"
[ "$n" -eq 2 ] || fail "expected 2 questions promoted into lead/, got $n"

PATH="$REAL_PATH"

echo "== tl_table: the plain form aligns, and an empty cell does not shift the row =="
# `column -t` was the obvious fallback and is wrong: BSD column drops empty fields, so one null
# path silently moves every later cell one column left. The awk measures instead.
rows="$(printf 'f1\task-user\ttest-regression\t\nf2\task-user\tscope-cap\tsrc/auth.ts\n')"
out="$(printf '%s\n' "$rows" | TL_NO_TABLE=1 tl_table "ID,CLASS,RULE,PATH")"
printf '%s\n' "$out" | grep -q '^  ID  CLASS     RULE             PATH$' || fail "header not aligned: $out"
printf '%s\n' "$out" | grep -q '^  f2  ask-user  scope-cap        src/auth.ts$' \
  || fail "empty cell in the previous row shifted this one: $out"
[ -z "$(printf '' | tl_table "A,B")" ] || fail "empty input should render nothing, not a bare header"

# Captured output must stay awk-parseable by COLUMN POSITION — `tl-cost report | awk '$1=="answer"
# {print $2}'` is a real caller (test/soak-fixes-smoke.sh), and gum's box-drawing would shift $1
# to "│". Stdout is not a tty here, so this is the real code path, not a stubbed one.
out="$(printf 'answer\t1000\t200\t0.4200\n' | tl_table "CATEGORY,INPUT,OUTPUT,COST_USD")"
case "$out" in *│*|*╭*) fail "captured table is boxed — every awk column assertion breaks";; esac
[ "$(printf '%s\n' "$out" | awk '$1=="answer"{print $2}')" = 1000 ] || fail "column 2 not parseable: $out"
[ "$(printf '%s\n' "$out" | awk '$1=="answer"{print $4}')" = "0.4200" ] || fail "column 4 not parseable: $out"

echo "== tl_table wraps a long cell onto more lines instead of cutting the question off =="
long="Reuse the existing secrets backend rather than introduce a new one, given the rotation window and the on-call rota?"
rows="$(printf 'q1\tdecided\t%s\nq2\topen\tshort one\n' "$long")"
# Decorating + a narrow terminal: the free-text column wraps, and its continuation lines carry
# blanks in the fixed columns so the row still reads as one record.
out="$(printf '%s\n' "$rows" | TL_DECORATE=1 TL_NO_TABLE=1 tl_table "QID,STATE,QUESTION")"
[ "$(printf '%s\n' "$out" | grep -c .)" -gt 3 ] || fail "long cell was not wrapped: $out"
printf '%s\n' "$out" | grep -q '^  q1 ' || fail "wrapped row lost its first line"
printf '%s\n' "$out" | grep -qE '^ +[a-z]' || fail "no continuation line with blank fixed columns: $out"
printf '%s\n' "$out" | grep -q 'on-call rota?' || fail "the tail of the question was cut off: $out"
# Every wrapped fragment must still be a word, not a mid-word chop.
printf '%s\n' "$out" | grep -q 'introduc$' && fail "wrapped mid-word instead of at a space"

# Captured output must NOT wrap: one physical line per record keeps awk column assertions working.
out="$(printf '%s\n' "$rows" | tl_table "QID,STATE,QUESTION")"
[ "$(printf '%s\n' "$out" | grep -c .)" = 3 ] || fail "captured table wrapped (header + 2 rows expected): $out"
[ "$(printf '%s\n' "$out" | awk '$1=="q1"{print $2}')" = decided ] || fail "captured row no longer parses"

echo "== when gum is installed: the right subcommand, and a cancel that propagates =="
# Two defects this pins down, both found by hand at a real terminal:
#  1. `gum write` is the multi-line textarea — it submits on ctrl-d, so pressing enter looks hung.
#     Prompts must use `gum input`, which submits on enter like every other prompt here.
#  2. A cancelled picker used to fall through to the plain prompt (two prompts for one answer) or
#     return "" (which the gate reads as "approve"). Cancel must propagate.
mkdir -p "$WORK/fakebin"
# Records its argv to a file, not stderr: tl_table silences gum's stderr so a broken table falls
# back cleanly, which would also hide the assertion.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "$GUM_ARGS"\necho picked\n' > "$WORK/fakebin/gum"
chmod +x "$WORK/fakebin/gum"
export GUM_ARGS="$WORK/gum.args"
[ "$(PATH="$WORK/fakebin:$PATH" tl_text K "the question" "the default" 2>/dev/null)" = picked ] \
  || fail "tl_text ignored gum"
args="$(cat "$GUM_ARGS")"
case "$args" in
  input*) ;;
  write*) fail "tl_text uses 'gum write' — it submits on ctrl-d and reads as a hung prompt" ;;
  *) fail "unexpected gum invocation: $args" ;;
esac
case "$args" in *--value=*) ;; *) fail "tl_text dropped --value (no editable default): $args";; esac
case "$args" in *--header=*) ;; *) fail "tl_text dropped --header (question invisible): $args";; esac

printf 'a\tb\n' | TL_DECORATE=1 PATH="$WORK/fakebin:$PATH" tl_table "C1,C2" >/dev/null
args="$(cat "$GUM_ARGS")"
case "$args" in
  table*--print*) ;;
  *) fail "tl_table did not shell out to 'gum table --print': $args" ;;
esac
case "$args" in *--columns=C1,C2*) ;; *) fail "tl_table dropped --columns: $args";; esac

printf '#!/bin/sh\nexit 130\n' > "$WORK/fakebin/gum"      # now stand in for esc / ctrl-c
# A gum that fails must not eat the rows — the table falls back rather than printing nothing.
out="$(printf 'a\tb\n' | PATH="$WORK/fakebin:$PATH" tl_table "C1,C2")"
printf '%s\n' "$out" | grep -q 'a  *b' || fail "gum failure swallowed the table rows: $out"
out="$(PATH="$WORK/fakebin:$PATH" tl_text K "the question" "the default" 2>/dev/null)" && \
  fail "cancelled tl_text returned success"
[ -z "$out" ] || fail "cancelled tl_text emitted '$out' instead of propagating the cancel"
out="$(PATH="$WORK/fakebin:$PATH" tl_choose K "pick" approve approve skip fix 2>/dev/null)" && \
  fail "cancelled tl_choose returned success — the gate would read '' as approve"
[ -z "$out" ] || fail "cancelled tl_choose emitted '$out'"

echo "== tl_spin runs the command, keeps its redirection, and propagates its exit status =="
# gum spin swallows stdout unless --show-output, so every caller keeps its own redirection INSIDE
# the command. If that contract breaks, tl-gate parses an empty failing-test list as "clean".
spin_out="$WORK/spin.out"
tl_spin "t" sh -c "printf 'a\nb\n' > '$spin_out'; exit 3" && fail "tl_spin swallowed exit status 3"
tl_spin "t" sh -c "exit 7" || rc=$?
[ "${rc:-0}" = 7 ] || fail "tl_spin did not propagate exit 7 (got ${rc:-0}) — tl-gate's trc breaks"
[ "$(tr '\n' ',' < "$spin_out")" = "a,b," ] || fail "tl_spin lost the command's redirected output"
TL_DECORATE=1 PATH="$WORK/fakebin:$PATH" tl_spin "t" true 2>/dev/null || true   # gum path, no crash

echo "== tl_page is a plain cat when nothing is watching =="
printf '# Title\n\nbody line\n' > "$WORK/p.md"
[ "$(tl_page "$WORK/p.md")" = "$(cat "$WORK/p.md")" ] || fail "tl_page altered captured output"
[ -z "$(tl_page "$WORK/nope.md")" ] || fail "tl_page on a missing file should be silent"

echo "== tl_log stays plain when captured, so tl-peek and the greps still work =="
[ "$(tl_log hello 2>&1)" = "tl: hello" ] || fail "tl_log changed shape: $(tl_log hello 2>&1)"

echo "== tl_confirm: gum when interactive, exit status IS the answer =="
printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "$GUM_ARGS"\nexit 0\n' > "$WORK/fakebin/gum"
PATH="$WORK/fakebin:$PATH" tl_confirm K "do it" y || fail "tl_confirm said no when gum said yes"
case "$(cat "$GUM_ARGS")" in confirm*--default*) ;; *) fail "tl_confirm did not use gum confirm: $(cat "$GUM_ARGS")";; esac
printf '#!/bin/sh\nexit 1\n' > "$WORK/fakebin/gum"
PATH="$WORK/fakebin:$PATH" tl_confirm K "do it" y && fail "tl_confirm said yes when gum said no"

echo "== pickers refuse rather than guess when there is nobody to ask =="
TL_YES=1 tl_pick_task && fail "tl_pick_task invented a task id non-interactively"
TL_YES=1 tl_pick_slug && fail "tl_pick_slug invented a slug non-interactively"

echo "== an exec that probes /dev/tty must not silence stderr for the rest of the script =="
# `exec 3</dev/tty 2>/dev/null` applies BOTH redirections to the shell permanently — the gate's
# "blocked: N finding(s) unresolved" refusal then vanished for exactly the owner who was sitting at
# a terminal. The braces are load-bearing; assert nobody drops them again.
cat > "$WORK/leak.sh" <<'SH'
#!/usr/bin/env bash
if { exec 3</dev/null; } 2>/dev/null; then echo survived >&2; fi
SH
chmod +x "$WORK/leak.sh"
[ "$("$WORK/leak.sh" 2>&1 1>/dev/null)" = survived ] || fail "grouped exec still swallows stderr"
grep -qE 'elif \{ exec 3</dev/tty; \} 2>/dev/null' "$BIN/tl-gate.sh" \
  || fail "tl-gate.sh lost the grouped exec — stderr after it goes to /dev/null"

echo "== tl-grill answer with no qid refuses without a tty (fail closed) =="
"$BIN/tl-grill.sh" answer tl-nope </dev/null >/dev/null 2>&1 && fail "interactive walk ran with no tty"

echo "PASS: prompt helpers, prune multi-select, fail-closed walk"
