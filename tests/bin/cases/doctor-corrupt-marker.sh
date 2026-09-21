#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #184: a marker that fails to parse used to read as setup_mode="" and fall
# through to auto mode with no warning. It must name the parse error and exit
# non-zero instead.

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT
P="$H/proj"
mkdir -p "$P"
echo '{"ai_kit_version": ' > "$P/.ai-kit-setup"

echo "=== doctor fails loud on a corrupt .ai-kit-setup ==="
RC=0
OUT="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" 2>&1)" || RC=$?
assert "exits non-zero" '[ "$RC" -ne 0 ]'
assert "names the file and the parse error" \
  'echo "$OUT" | grep -q "\.ai-kit-setup: Expecting"'
assert "does not fall through to the global-install checks" \
  '! echo "$OUT" | grep -q "^Global install"'

print_summary_and_exit
