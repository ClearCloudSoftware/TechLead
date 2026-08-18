#!/usr/bin/env bash
# claude-security.sh — the Security review axis, backed by Claude headless. Reviews the change diff for
# vulnerabilities ONLY — style, naming, and design belong to the Standards axis and are out of scope
# here (overlap wastes tokens and produces duplicate findings). This axis BLOCKS at the delivery gate.
# Wire with: export TL_SECURITY_CMD="$TL_HOME/adapters/claude-security.sh"
#
# Contract: read the change diff from the file at TL_SEC_DIFF; emit ONE tab-separated line per finding:
#   security-vulnerability<TAB>detail<TAB>path
# Clean diff = zero lines, exit 0. Exit non-zero only on harness failure (the caller turns that into
# a blocking security-unrunnable finding — fail closed).
set -eu
diff="$(cat "${TL_SEC_DIFF:?}" 2>/dev/null || true)"

prompt="You are the Security review axis. Review ONLY this change diff for security vulnerabilities:
injection (shell/SQL/template), missing or broken authn/authz, secrets or credentials in code or
config, path traversal, unsafe deserialization or eval of untrusted input, SSRF, insecure temp files
or permissions, and disabled security controls (TLS verification, sandboxing, input validation at a
trust boundary).

OUT of scope — do not report: style, naming, duplication, performance, missing tests, design taste.
Those belong to a different reviewer.

The change diff:
$diff

Emit ONLY one tab-separated line per finding and nothing else:
security-vulnerability<TAB>detail<TAB>path
- detail = one line: the vulnerability + why it is exploitable, quoting the hunk briefly. No tabs.
- path = the file (path:line if you can point at the line), or empty when not file-specific.
Examples:
security-vulnerability	deploy.sh builds a shell command from unquoted user input \$1 — command injection	bin/deploy.sh:14
security-vulnerability	AWS secret key committed in config default	config/settings.py:7
Report nothing for a clean diff. Only findings in the diff itself — do not audit unchanged code."

out="$(claude -p "$prompt" --output-format json --permission-mode default --max-turns 4 </dev/null)"
printf '%s' "$out" | "$TL_HOME/bin/tl-cost.sh" record-json "${TL_SEC_ID:-(security)}" security || true
# no in-adapter filtering (unlike claude-standards): this axis blocks the gate, so tl-security.sh must
# see malformed output to fail closed on it — a pre-filter here would make a confused judge look clean.
printf '%s' "$out" | jq -r '.result // empty' | grep -v '^$' || true
