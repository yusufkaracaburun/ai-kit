#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

DEDUPE="$AIKIT/bin/ai-kit-dedupe.sh"

echo "=== ai-kit-dedupe: basic invocation ==="
# section: ai-kit-dedupe

# Smoke: --help exits 0 and prints usage.
assert "dedupe --help exits 0" '"$DEDUPE" --help >/dev/null 2>&1'
assert "dedupe --help prints usage" '"$DEDUPE" --help 2>&1 | grep -q "Scan for ai-kit duplication"'

# Smoke: empty target dir = clean (no personal-skill shadow from temp, no
# project rules, no settings). Exit 0.
EMPTY_TMP=$(mktemp -d)
set +e
"$DEDUPE" "$EMPTY_TMP" >/dev/null 2>&1
EMPTY_EXIT=$?
set -e
assert "dedupe empty target: exit 0 when no project orphans/notes" '[ "$EMPTY_EXIT" -eq 0 ] || [ "$EMPTY_EXIT" -eq 1 ]'
# Exit may be 1 if the user's ~/.claude/skills shadows any plugin skill on
# this machine. That's a real duplicate, not a test failure.

set +e
JSON_OUT="$("$DEDUPE" "$EMPTY_TMP" --json 2>&1)"
set -e
assert "dedupe --json emits parseable JSON" 'echo "$JSON_OUT" | python3 -c "import json,sys; json.load(sys.stdin)"'
assert "dedupe --json has dup_skills key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"dup_skills\" in d"'
assert "dedupe --json has dup_agents key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"dup_agents\" in d"'
assert "dedupe --json has orphan_rules key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"orphan_rules\" in d"'
assert "dedupe --json has total field" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"total\"], int)"'
rm -rf "$EMPTY_TMP"

echo "=== ai-kit-dedupe: orphan rule detection ==="
# section: ai-kit-dedupe-orphan

# Stage a project with one valid emitted rule + one orphan.
PROJ_TMP=$(mktemp -d)
mkdir -p "$PROJ_TMP/.cursor/rules"
# Pick a rule we know exists in the plugin.
touch "$PROJ_TMP/.cursor/rules/ai-kit-context-discipline.mdc"
# Stage an orphan — name that doesn't match any rule in standards/rules/.
touch "$PROJ_TMP/.cursor/rules/ai-kit-totally-fake-rule-xyz.mdc"

set +e
JSON_ORPHAN="$("$DEDUPE" "$PROJ_TMP" --json 2>&1)"
set -e
assert "dedupe orphan detected" 'echo "$JSON_ORPHAN" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(\"totally-fake-rule-xyz\" in r for r in d[\"orphan_rules\"])"'
assert "dedupe valid rule NOT flagged orphan" 'echo "$JSON_ORPHAN" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not any(\"context-discipline\" in r for r in d[\"orphan_rules\"])"'

# --fix prints rm command for the orphan, doesn't execute.
set +e
FIX_OUT="$("$DEDUPE" "$PROJ_TMP" --fix 2>&1)"
set -e
assert "dedupe --fix prints rm for orphan" 'echo "$FIX_OUT" | grep -q "rm \".*totally-fake-rule-xyz.mdc\""'
assert "dedupe --fix did NOT execute (orphan file still present)" '[ -f "$PROJ_TMP/.cursor/rules/ai-kit-totally-fake-rule-xyz.mdc" ]'

rm -rf "$PROJ_TMP"

echo "=== ai-kit-dedupe: unknown flag rejected ==="
# section: ai-kit-dedupe-flags
assert "dedupe rejects unknown flag" '! "$DEDUPE" --bogus-flag >/dev/null 2>&1'

print_summary_and_exit
