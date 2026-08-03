#!/usr/bin/env bash
# tl-scrub.sh — content-level secret guard (§3.9 counterpart). Scans files (or dirs, *.md within)
# for secret shapes before their content is committed into lead/ or decisions/. It NEVER edits or
# strips: on a hit it fails closed (exit 3) and names the offender, so the write escalates to the
# owner rather than silently dropping something load-bearing (a false positive costs ten seconds).
# Deterministic deny-patterns only — no LLM, no network. Tune the list below as scars accrue.
#
# Usage:  tl-scrub.sh PATH...        # files scanned directly; dirs scanned recursively for *.md
set -eu
BIN="$(cd "$(dirname "$0")" && pwd)"; . "$BIN/tl-common.sh"
[ "$#" -gt 0 ] || tl_die "usage: tl-scrub PATH..."

# Deny-patterns: "<label> <ERE>", one per line, split on the first space (labels carry none).
# High signal; generic-secret needs an 8+ char value so prose ("token: q3") does not trip it.
deny() {
cat <<'EOF'
private-key -----BEGIN [A-Z ]*PRIVATE KEY-----
aws-access-key-id AKIA[0-9A-Z]{16}
github-token gh[pousr]_[A-Za-z0-9]{20,}
slack-token xox[baprs]-[A-Za-z0-9-]{10,}
generic-secret (password|passwd|secret|api[_-]?key|access[_-]?token|bearer)[[:space:]"':=]+[A-Za-z0-9+/_.=-]{8,}
internal-host [A-Za-z0-9._-]+\.(internal|corp|intranet)([/:]|[[:space:]]|$)
EOF
}

# Gather targets: file args directly; dir args -> their *.md.
files=()
for p in "$@"; do
  if [ -f "$p" ]; then files+=("$p")
  elif [ -d "$p" ]; then while IFS= read -r f; do files+=("$f"); done < <(find "$p" -type f -name '*.md'); fi
done
[ "${#files[@]}" -gt 0 ] || exit 0   # nothing to scan is not a failure

found=0
while read -r label ere; do
  [ -n "${ere:-}" ] || continue
  while IFS= read -r hit; do
    tl_log "possible secret [$label] — $hit"
    found=1
  done < <(grep -HnEI "$ere" "${files[@]}" 2>/dev/null || true)
done < <(deny)

[ "$found" -eq 0 ] || tl_die "scrub blocked: possible secret(s) above. Escalating for owner review — NOT stripping. Redact by hand (or confirm it is safe), then re-run." 3
exit 0
