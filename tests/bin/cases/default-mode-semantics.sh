#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== default_mode semantics parity (#144) ==="
# section: default_mode semantics
# `default_mode: always-on` is enforcement on Cursor (alwaysApply: true) and
# only a comment on Claude Code — no injection primitive reads it there. That
# asymmetry is documented in bin/lib/emitters/README.md and docs/adr; this
# test pins the current, verified behaviour so a future edit can't silently
# change what a mode value does on either host, or add an emitter whose
# emit_<agent>() accepts $mode and never looks at it.

TMP=$(mktemp -d)

"$AIKIT/bin/emit-rules.sh" "$TMP" --rules git-hygiene --agents cursor --mode always-on >/dev/null
cp "$TMP/.cursor/rules/git-hygiene.mdc" "$TMP/cursor-always.mdc"
"$AIKIT/bin/emit-rules.sh" "$TMP" --rules git-hygiene --agents cursor --mode on-demand >/dev/null
cp "$TMP/.cursor/rules/git-hygiene.mdc" "$TMP/cursor-on-demand.mdc"

assert "cursor: always-on sets alwaysApply: true" \
  'grep -q "^alwaysApply: true$" "$TMP/cursor-always.mdc"'
assert "cursor: on-demand sets alwaysApply: false" \
  'grep -q "^alwaysApply: false$" "$TMP/cursor-on-demand.mdc"'

"$AIKIT/bin/emit-rules.sh" "$TMP" --rules git-hygiene --agents claude-code --mode always-on >/dev/null
cp "$TMP/.claude/rules/git-hygiene.md" "$TMP/claude-always.md"
"$AIKIT/bin/emit-rules.sh" "$TMP" --rules git-hygiene --agents claude-code --mode on-demand >/dev/null
cp "$TMP/.claude/rules/git-hygiene.md" "$TMP/claude-on-demand.md"

assert "claude-code: always-on recorded in header comment" \
  'grep -q "Mode: always-on" "$TMP/claude-always.md"'
assert "claude-code: on-demand recorded in header comment" \
  'grep -q "Mode: on-demand" "$TMP/claude-on-demand.md"'
# The header line is the only thing mode changes on Claude Code today. Strip
# it from both and the rest must be byte-identical — if it isn't, Claude Code
# has grown real enforcement behind the mode value without the ADR call
# (docs/adr, emitters/README.md) being updated to say so.
assert "claude-code: mode is decorative, not structural (#144)" \
  'diff <(grep -v "^<!-- Mode:" "$TMP/claude-always.md") <(grep -v "^<!-- Mode:" "$TMP/claude-on-demand.md") >/dev/null'

# A new emitter that declares $mode as its 4th argument (per the contract in
# emitters/README.md) but never reads it would repeat the Claude Code gap
# silently. Every emitter file must reference $mode somewhere in its body.
for f in "$AIKIT"/bin/lib/emitters/*.sh; do
  agent="$(basename "$f" .sh)"
  assert "emitter '$agent' reads \$mode" 'grep -qE "\\\$\{?mode\}?" "$f"'
done

rm -rf "$TMP"

print_summary_and_exit
