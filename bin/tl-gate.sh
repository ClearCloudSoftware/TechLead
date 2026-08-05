#!/usr/bin/env bash
# tl-gate.sh — the delivery gate for a change task (§3.13, L2). Runs the project's tests, compares
# the failing set against the recorded baseline, checks scope + danger paths, and emits a structured
# findings.json — not a pass/fail bit. Fail-closed: every finding defaults to `ask-user` until a real
# review-rubric exists (Epic 8). Exits non-zero while any finding is unresolved or marked `fix`.
# tl: `eval` on operator test_command — trusted registry only; assumes no spaces in changed paths
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
id="${1:?usage: tl-gate ID}"
[ "$(tl_meta_get "$id" kind)" = change ] || tl_die "gate is for change tasks"
wt="$(tl_meta_get "$id" worktree)"; base="$(tl_meta_get "$id" base)"; pname="$(tl_meta_get "$id" pname)"
mkdir -p "$TL_DATA/$id"; findings="$TL_DATA/$id/findings.json"

pget() { "$BIN/tl-project.sh" get "$pname" "$1" 2>/dev/null || true; }
cmd="$(pget test_command)"; baseline="$(pget baseline)"; danger="$(pget danger_paths)"; maxf="$(pget max_files_changed)"
[ -n "$baseline" ] && [ -f "$baseline" ] || baseline=/dev/null

# 1. tests vs baseline — new failures are regressions (§2.7)
curfail="$(mktemp)"; ( cd "$wt" && eval "${cmd:-true}" ) 2>/dev/null | sort -u > "$curfail" || true
regressions="$(comm -13 "$baseline" "$curfail" 2>/dev/null || true)"

# 2. scope + danger over the changed set
changed="$(git -C "$wt" diff --name-only "$base"..HEAD 2>/dev/null || true)"
nfiles="$(printf '%s\n' "$changed" | grep -c . || true)"

# 3. collect findings (rule<TAB>detail), then render to JSON with fail-closed ask-user class
tmp="$(mktemp)"; : > "$tmp"
for t in $regressions; do [ -n "$t" ] && printf 'test-regression\tnewly failing: %s\n' "$t" >> "$tmp"; done
if [ -n "$maxf" ] && [ "${nfiles:-0}" -gt "$maxf" ]; then
  printf 'scope-cap-exceeded\t%s files changed > max %s\n' "$nfiles" "$maxf" >> "$tmp"; fi
for f in $changed; do for g in $danger; do
  case "$f" in $g) printf 'danger-path\t%s touches danger zone %s\n' "$f" "$g" >> "$tmp";; esac
done; done
jq -R -s -c 'split("\n")|map(select(length>0)|split("\t"))|to_entries
  |map({id:("f"+((.key+1)|tostring)),class:"ask-user",rule:.value[0],detail:.value[1],resolved:null})' "$tmp" > "$findings"
rm -f "$curfail" "$tmp"

count="$(jq 'length' "$findings")"
echo "tl: gate for $id — $nfiles file(s) changed, $count finding(s)"
git -C "$wt" --no-pager diff --stat "$base"..HEAD 2>/dev/null | sed 's/^/  /' || true

# 4. resolve each finding (§2.3.1 approve/fix/skip). Non-interactive: TL_APPROVE=yes uses TL_RESOLVE.
if [ "$count" -gt 0 ]; then
  jq -r '.[]|"  ["+.id+"] "+.rule+": "+.detail' "$findings"
  if [ "${TL_APPROVE:-}" = "yes" ]; then
    jq --arg r "${TL_RESOLVE:-approve}" 'map(.resolved=$r)' "$findings" > "$findings.t" && mv "$findings.t" "$findings"
  elif exec 3</dev/tty 2>/dev/null; then
    for fid in $(jq -r '.[].id' "$findings"); do
      printf 'resolve [%s] approve/skip/fix? [approve] ' "$fid"
      read -r a <&3 || a=approve; a="${a:-approve}"
      jq --arg i "$fid" --arg a "$a" 'map(if .id==$i then .resolved=$a else . end)' "$findings" > "$findings.t" && mv "$findings.t" "$findings"
    done
    exec 3<&-
  else
    # No controlling tty and TL_APPROVE unset: we cannot reach a human. Do NOT default to approve —
    # opening /dev/tty and letting it fail silently merged regressions in headless/cron/nested runs.
    # Fail closed (§2.3.1, §3.9): leave findings unresolved so step 5 blocks. `[ -r /dev/tty ]` is not
    # enough — the node is world-readable but open() still fails, so we test by actually opening it.
    tl_log "no tty to resolve $count finding(s) — leaving them unresolved (fail closed). Resolve non-interactively with: TL_APPROVE=yes TL_RESOLVE=approve|skip|fix"
  fi
fi

# 5. gate result — refuse while anything is unresolved or needs a fix (fail closed, §2.3.1)
blocking="$(jq '[.[]|select(.resolved==null or .resolved=="fix")]|length' "$findings")"
[ "$blocking" -eq 0 ] || tl_die "gate blocked: $blocking finding(s) unresolved or marked fix" 3
echo "tl: gate passed for $id"
