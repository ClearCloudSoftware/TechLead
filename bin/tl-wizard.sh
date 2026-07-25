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
  if command -v gum >/dev/null 2>&1; then gum choose --selected="$def" "$@"; return 0; fi
  if command -v fzf >/dev/null 2>&1; then printf '%s\n' "$@" | fzf --select-1 --prompt="$prompt> "; return 0; fi
  local i=1 o pick                                   # plain fallback: numbered menu, empty -> default
  for o in "$@"; do printf '  %d) %s\n' "$i" "$o" >&2; i=$((i+1)); done
  printf 'tl: %s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r pick || pick=""
  [ -z "$pick" ] && { printf '%s\n' "$def"; return 0; }
  case "$pick" in *[!0-9]*) printf '%s\n' "$pick"; return 0;; esac   # typed a literal value
  i=1; for o in "$@"; do [ "$i" = "$pick" ] && { printf '%s\n' "$o"; return 0; }; i=$((i+1)); done
  printf '%s\n' "$def"                               # out of range -> default
}
