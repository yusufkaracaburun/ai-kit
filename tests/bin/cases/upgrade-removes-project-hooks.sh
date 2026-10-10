#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #205: the four advisory hooks moved to the plugin's hooks.json. A project set
# up earlier still holds copies in .claude/hooks/ wired in settings.json, which
# would fire next to the plugin's. /ai:upgrade removes both and nothing else.

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
P="$T/p" M="$T/m" S="$T/s"
mkdir -p "$P" "$M" "$S"
CURRENT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"
printf '{\n  "ai_kit_version": "%s",\n  "branches": {}\n}\n' "$CURRENT_VERSION" > "$P/.ai-kit-setup"
mkdir -p "$P/.claude/hooks"
for s in search-delegation-check build-delegation-check phase-check context-drift-check; do
  echo '#!/usr/bin/env bash' > "$P/.claude/hooks/$s.sh"
done
echo '#!/usr/bin/env bash' > "$P/.claude/hooks/rename-detector.sh"
cat > "$P/.claude/settings.json" <<'JSON'
{
  "env": {"FOO": "bar"},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash|Grep|Glob", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/search-delegation-check.sh"}]},
      {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/build-delegation-check.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/context-drift-check.sh"}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/rename-detector.sh"}]}
    ]
  },
  "permissions": {"allow": ["Bash(ls *)"]}
}
JSON

echo "=== upgrade removes the project hook copies and their settings entries ==="
# section: upgrade-removes-project-hooks
bash "$AIKIT/bin/ai-kit-upgrade.sh" "$P" >/dev/null 2>&1
for s in search-delegation-check build-delegation-check phase-check context-drift-check; do
  assert "$s.sh copy removed" '[ ! -e "$P/.claude/hooks/$s.sh" ]'
done
assert "no settings entry names a removed hook" \
  '! grep -qE "(search-delegation-check|build-delegation-check|phase-check|context-drift-check)\.sh" "$P/.claude/settings.json"'
assert "unrelated hook file kept" '[ -f "$P/.claude/hooks/rename-detector.sh" ]'
assert "unrelated hook entry and other keys kept" 'python3 -c "
import json
d = json.load(open(\"$P/.claude/settings.json\"))
assert d[\"env\"] == {\"FOO\": \"bar\"}, d
assert d[\"permissions\"] == {\"allow\": [\"Bash(ls *)\"]}, d
assert d[\"hooks\"] == {\"PostToolUse\": [{\"matcher\": \"Bash\", \"hooks\": [{\"type\": \"command\", \"command\": \"\${CLAUDE_PROJECT_DIR}/.claude/hooks/rename-detector.sh\"}]}]}, d
"'

echo "=== a second upgrade is a no-op ==="
# section: upgrade-removes-project-hooks-idempotent
BEFORE="$(cat "$P/.claude/settings.json")"
bash "$AIKIT/bin/ai-kit-upgrade.sh" "$P" >/dev/null 2>&1
assert "second run leaves settings.json byte-identical" '[ "$BEFORE" = "$(cat "$P/.claude/settings.json")" ]'

echo "=== unwire_hook matches the script name exactly ==="
# section: unwire-hook-exact-name
# shellcheck source=../../../bin/lib/settings-hooks.sh
source "$AIKIT/bin/lib/settings-hooks.sh"
cat > "$P/bak.json" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh.bak"}]}]}}
JSON
BAK_BEFORE="$(cat "$P/bak.json")"
unwire_hook "$P/bak.json" phase-check.sh >/dev/null
assert "phase-check.sh.bak survives unwire of phase-check.sh" '[ "$BAK_BEFORE" = "$(cat "$P/bak.json")" ]'

echo "=== unwire_hook keeps non-ASCII characters literal ==="
# section: unwire-hook-non-ascii
cat > "$P/utf.json" <<'JSON'
{"env": {"NAME": "é"}, "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh"}]}]}}
JSON
unwire_hook "$P/utf.json" phase-check.sh >/dev/null
assert "non-ASCII value written as the literal character" 'grep -q "\"é\"" "$P/utf.json"'

echo "=== upgrade keeps the copies when settings.json is malformed ==="
# section: upgrade-malformed-settings-keeps-copies
cp "$P/.ai-kit-setup" "$M/.ai-kit-setup"
mkdir -p "$M/.claude/hooks"
for s in search-delegation-check build-delegation-check phase-check context-drift-check; do
  echo '#!/usr/bin/env bash' > "$M/.claude/hooks/$s.sh"
done
echo '{ not json' > "$M/.claude/settings.json"
set +e
bash "$AIKIT/bin/ai-kit-upgrade.sh" "$M" >/dev/null 2>&1
M_RC=$?
set -e
assert "upgrade exits 0 on malformed settings.json" '[ "$M_RC" -eq 0 ]'
for s in search-delegation-check build-delegation-check phase-check context-drift-check; do
  assert "$s.sh copy kept when unwire failed" '[ -f "$M/.claude/hooks/$s.sh" ]'
done
assert "malformed settings.json byte-identical" '[ "$(cat "$M/.claude/settings.json")" = "{ not json" ]'

echo "=== upgrade keeps a foreign command sharing a block with an ai-kit copy ==="
# section: upgrade-shared-block
cp "$P/.ai-kit-setup" "$S/.ai-kit-setup"
mkdir -p "$S/.claude/hooks"
echo '#!/usr/bin/env bash' > "$S/.claude/hooks/phase-check.sh"
cat > "$S/.claude/settings.json" <<'JSON'
{"hooks": {"UserPromptSubmit": [{"hooks": [
  {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh"},
  {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/my-own.sh"}
]}]}}
JSON
bash "$AIKIT/bin/ai-kit-upgrade.sh" "$S" >/dev/null 2>&1
assert "foreign command kept in the same block" 'python3 -c "
import json
d = json.load(open(\"$S/.claude/settings.json\"))
assert d[\"hooks\"] == {\"UserPromptSubmit\": [{\"hooks\": [{\"type\": \"command\", \"command\": \"\${CLAUDE_PROJECT_DIR}/.claude/hooks/my-own.sh\"}]}]}, d
"'

print_summary_and_exit
