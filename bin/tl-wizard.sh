#!/usr/bin/env bash
# tl-wizard.sh — interactive prompt helpers shared by the setup wizards (tl-init/onboard/new).
# Sourced AFTER tl-common (not by it: only the wizards want prompt code, not every mechanic script).
#
# Non-interactive (§ mirrors TL_APPROVE=yes): when TL_YES is set or stdin is not a tty, every prompt
# takes its stated default. A per-field TL_ANSWER_<KEY> env var overrides any prompt, interactive or
# not — so the wizards are fully scriptable/CI-friendly (E11/W5). Prompts go to stderr; the chosen
# value is the only thing on stdout, so `x="$(tl_ask ...)"` captures just the answer.

tl_noninteractive() { [ -n "${TL_YES:-}" ] || [ ! -t 0 ]; }

tl_ask() {  # KEY "prompt" "default" -> answer on stdout
  local key="$1" prompt="$2" def="$3" ov ans
  eval "ov=\${TL_ANSWER_${key}:-}"
  [ -n "$ov" ] && { printf '%s\n' "$ov"; return 0; }
  tl_noninteractive && { printf '%s\n' "$def"; return 0; }
  printf 'tl: %s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r ans || ans=""
  printf '%s\n' "${ans:-$def}"
}

tl_confirm() {  # KEY "prompt" "y|n default" -> exit 0 for yes
  local a; a="$(tl_ask "$1" "$2 (y/n)" "$3")"
  case "$a" in y|Y|yes|YES|true|1) return 0;; *) return 1;; esac
}

tl_choose() {  # KEY "prompt" default opt1 opt2 ... -> chosen on stdout (gum/fzf if present)
  local key="$1" prompt="$2" def="$3"; shift 3
  local ov; eval "ov=\${TL_ANSWER_${key}:-}"
  [ -n "$ov" ] && { printf '%s\n' "$ov"; return 0; }
  tl_noninteractive && { printf '%s\n' "$def"; return 0; }
  # --header carries the question: gum paints over the scrollback, so anything the caller echoed
  # first can be gone by the time the picker is on screen.
  # Cancel (esc / ctrl-c) returns non-zero and we propagate it — the caller's `set -e` aborts.
  # Swallowing it would hand back an empty string, which reads as "took the default": a cancelled
  # gate prompt would silently approve a finding.
  if command -v gum >/dev/null 2>&1; then gum choose --header="$prompt" --selected="$def" "$@"; return $?; fi
  if command -v fzf >/dev/null 2>&1; then printf '%s\n' "$@" | fzf --select-1 --prompt="$prompt> "; return $?; fi
  local i=1 o pick                                   # plain fallback: numbered menu, empty -> default
  for o in "$@"; do printf '  %d) %s\n' "$i" "$o" >&2; i=$((i+1)); done
  printf 'tl: %s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r pick || pick=""
  [ -z "$pick" ] && { printf '%s\n' "$def"; return 0; }
  case "$pick" in *[!0-9]*) printf '%s\n' "$pick"; return 0;; esac   # typed a literal value
  i=1; for o in "$@"; do [ "$i" = "$pick" ] && { printf '%s\n' "$o"; return 0; }; i=$((i+1)); done
  printf '%s\n' "$def"                               # out of range -> default
}

tl_text() {  # KEY "prompt" "default" -> free text on stdout (gum input if present, else one line)
  # `gum input`, NOT `gum write`: write is the multi-line textarea and submits on ctrl-d, which
  # reads as a hung prompt to anyone who just pressed enter. input submits on enter like every other
  # prompt here, and --value pre-fills an EDITABLE default — the `read -e -i` behaviour bash 3.2
  # can't give us. Without gum the default is shown instead, and empty input keeps it.
  local key="$1" prompt="$2" def="$3" ov ans
  eval "ov=\${TL_ANSWER_${key}:-}"
  [ -n "$ov" ] && { printf '%s\n' "$ov"; return 0; }
  tl_noninteractive && { printf '%s\n' "$def"; return 0; }
  if command -v gum >/dev/null 2>&1; then
    # Cancel propagates (see tl_choose) rather than quietly demoting to the plain prompt below —
    # falling through mid-question is how you end up staring at two different prompts for one answer.
    ans="$(gum input --header="$prompt" --value="$def" --char-limit=0)" || return $?
    printf '%s\n' "${ans:-$def}"; return 0
  fi
  printf 'tl: %s\n' "$prompt" >&2
  [ -n "$def" ] && printf '    %s[enter keeps: %s]%s\n' "$TL_C_DIM" "$def" "$TL_C_0" >&2
  printf '> ' >&2
  IFS= read -r ans || ans=""
  printf '%s\n' "${ans:-$def}"
}

tl_pick_many() {  # KEY "prompt" opt1 opt2 ... -> the KEPT options, one per line. Default: keep all.
  # Multi-select is what "open the file and delete the lines you don't want" actually is.
  # TL_ANSWER_<KEY> takes a semicolon-separated list of literal options.
  local key="$1" prompt="$2"; shift 2
  local ov; eval "ov=\${TL_ANSWER_${key}:-}"
  [ -n "$ov" ] && { printf '%s\n' "$ov" | tr ';' '\n'; return 0; }
  tl_noninteractive && { printf '%s\n' "$@"; return 0; }
  if command -v gum >/dev/null 2>&1; then gum choose --no-limit --header="$prompt" "$@"; return $?; fi
  if command -v fzf >/dev/null 2>&1; then printf '%s\n' "$@" | fzf --multi --prompt="$prompt> "; return $?; fi
  local i=1 o n pick                                 # plain fallback: numbered list, keep-by-number
  for o in "$@"; do printf '  %s%d)%s %s\n' "$TL_C_KEY" "$i" "$TL_C_0" "$o" >&2; i=$((i+1)); done
  printf 'tl: %s — numbers to KEEP, space-separated [all]: ' "$prompt" >&2
  IFS= read -r pick || pick=""
  [ -z "$pick" ] && { printf '%s\n' "$@"; return 0; }
  for n in $pick; do
    case "$n" in ''|*[!0-9]*) continue;; esac        # ignore junk rather than guess
    [ "$n" -ge 1 ] && [ "$n" -le $# ] && printf '%s\n' "${!n}"
  done
  return 0
}
