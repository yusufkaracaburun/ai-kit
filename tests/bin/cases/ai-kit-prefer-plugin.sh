#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ai-kit-prefer-plugin.sh toggles a marker file at ~/.config/ai-kit/prefer-plugin.
# Every case here runs with HOME redirected into a temp dir, so the
# developer's real machine is never touched.

prefer_plugin() {
  # prefer_plugin <sandbox_home> [args...]
  local home="$1"; shift
  HOME="$home" bash "$AIKIT/bin/ai-kit-prefer-plugin.sh" "$@"
}

H=$(mktemp -d)

echo "=== status ==="
OUT=$(prefer_plugin "$H" status)
assert "status OFF when marker absent" 'grep -q "prefer-plugin: OFF" <<<"$OUT"'
RC=0; prefer_plugin "$H" >/dev/null || RC=$?
assert "default action (no arg) is status, exits 0" '[ "$RC" -eq 0 ]'

echo "=== on ==="
OUT=$(prefer_plugin "$H" on)
assert "on creates the marker file" '[ -f "$H/.config/ai-kit/prefer-plugin" ]'
assert "on reports the opt-out is active" 'grep -q "prefer-plugin opt-out active" <<<"$OUT"'
OUT=$(prefer_plugin "$H" status)
assert "status ON after on" 'grep -q "prefer-plugin: ON" <<<"$OUT"'

echo "=== off ==="
OUT=$(prefer_plugin "$H" off)
assert "off removes the marker" '[ ! -f "$H/.config/ai-kit/prefer-plugin" ]'
assert "off reports the removal" 'grep -q "prefer-plugin opt-out removed" <<<"$OUT"'
OUT=$(prefer_plugin "$H" off)
assert "second off is idempotent" 'grep -q "already absent" <<<"$OUT"'

echo "=== unknown action ==="
RC=0; ERR=$(prefer_plugin "$H" bogus 2>&1) || RC=$?
assert "unknown action exits 1" '[ "$RC" -eq 1 ]'
assert "unknown action names the bad action" 'grep -q "Unknown action: bogus" <<<"$ERR"'

rm -rf "$H"
print_summary_and_exit
