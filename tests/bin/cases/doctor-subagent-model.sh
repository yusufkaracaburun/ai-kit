#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #280: without CLAUDE_CODE_SUBAGENT_MODEL a general-purpose subagent runs on
# the lead's model, so doctor warns until env or a settings.json sets it.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
H="$TMP/home"
P="$TMP/proj"
mkdir -p "$H/.claude" "$P/.claude"

run_doctor() {
  HOME="$H" env -u CLAUDE_CODE_SUBAGENT_MODEL "$@" bash "$DOCTOR" "$P" --project-only 2>&1 || true
}

echo "=== unset everywhere ==="
OUT="$(run_doctor)"
assert "unset subagent model is warned with the settings recipe" \
  'echo "$OUT" | grep -qE "^  warn .*CLAUDE_CODE_SUBAGENT_MODEL unset"'

echo "=== set in env ==="
OUT="$(run_doctor CLAUDE_CODE_SUBAGENT_MODEL=sonnet)"
assert "env value silences the warning" '! echo "$OUT" | grep -q "SUBAGENT_MODEL unset"'

echo "=== set in user settings ==="
echo '{"env":{"CLAUDE_CODE_SUBAGENT_MODEL":"sonnet"}}' > "$H/.claude/settings.json"
OUT="$(run_doctor)"
assert "user settings env silences the warning" '! echo "$OUT" | grep -q "SUBAGENT_MODEL unset"'
rm "$H/.claude/settings.json"

echo "=== set in project settings ==="
echo '{"env":{"CLAUDE_CODE_SUBAGENT_MODEL":"sonnet"}}' > "$P/.claude/settings.json"
OUT="$(run_doctor)"
assert "project settings env silences the warning" '! echo "$OUT" | grep -q "SUBAGENT_MODEL unset"'

echo "=== set in project settings.local ==="
rm "$P/.claude/settings.json"
echo '{"env":{"CLAUDE_CODE_SUBAGENT_MODEL":"sonnet"}}' > "$P/.claude/settings.local.json"
OUT="$(run_doctor)"
assert "project settings.local env silences the warning" '! echo "$OUT" | grep -q "SUBAGENT_MODEL unset"'
rm "$P/.claude/settings.local.json"

echo "=== key outside env does not count ==="
echo '{"CLAUDE_CODE_SUBAGENT_MODEL":"sonnet"}' > "$P/.claude/settings.json"
OUT="$(run_doctor)"
assert "top-level key is still warned" 'echo "$OUT" | grep -q "SUBAGENT_MODEL unset"'

print_summary_and_exit
