#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/search-delegation-check.sh"

# The hook must fire on wide sweeps and stay silent on narrow ones. If it fired
# on every Grep it would inject more context than it saves — that distinction is
# the whole point, so it is what these cases pin down.
fire() {
  # fire <project_dir> <payload_json>  -> prints additionalContext, empty if silent
  CLAUDE_PROJECT_DIR="$1" bash "$HOOK" <<<"$2" |
    python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null || true
}

echo "=== search-delegation-check: wide vs narrow ==="
# section: search-delegation-check
TMP_H=$(mktemp -d)

OUT=$(fire "$TMP_H" '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ."}}')
assert "bash grep fires" '[ -n "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Bash","tool_input":{"command":"rg pattern"}}')
assert "bash rg fires" '[ -n "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')
assert "bash ls silent" '[ -z "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Grep","tool_input":{"pattern":"x"}}')
assert "Grep without path fires (wide sweep)" '[ -n "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Grep","tool_input":{"pattern":"x","path":"src/auth"}}')
assert "Grep with path is silent (already scoped)" '[ -z "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Glob","tool_input":{"pattern":"**/*.ts"}}')
assert "Glob without path fires" '[ -n "$OUT" ]'

set +e
bash "$HOOK" </dev/null >/dev/null 2>&1
EMPTY_RC=$?
set -e
assert "empty payload exits clean" '[ "$EMPTY_RC" -eq 0 ]'

echo "=== search-delegation-check: message switches on graphify ==="
OUT=$(fire "$TMP_H" '{"tool_name":"Grep","tool_input":{"pattern":"x"}}')
assert "no graph -> delegate-to-subagent message" 'grep -q "sub-agent" <<<"$OUT"'

mkdir -p "$TMP_H/graphify-out"
echo '{}' > "$TMP_H/graphify-out/graph.json"
OUT=$(fire "$TMP_H" '{"tool_name":"Grep","tool_input":{"pattern":"x"}}')
assert "graph present -> graphify message" 'grep -q "graphify query" <<<"$OUT"'
rm -rf "$TMP_H"

echo "=== apply-search-delegation-hook ==="
# section: apply-search-delegation-hook
TMP_A=$(mktemp -d)
"$AIKIT/bin/apply-search-delegation-hook.sh" "$TMP_A" >/dev/null
assert "hook copied + executable" '[ -x "$TMP_A/.claude/hooks/search-delegation-check.sh" ]'
assert "PreToolUse wired with Bash|Grep|Glob matcher" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
pre = d[\"hooks\"][\"PreToolUse\"]
assert len(pre) == 1, pre
assert pre[0][\"matcher\"] == \"Bash|Grep|Glob\", pre[0]
"'

"$AIKIT/bin/apply-search-delegation-hook.sh" "$TMP_A" >/dev/null
assert "idempotent: second run does not stack" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
assert len(d[\"hooks\"][\"PreToolUse\"]) == 1
"'
rm -rf "$TMP_A"

echo "=== apply-search-delegation-hook: legacy graphify nudge is replaced ==="
# A project wired by an older /ai:recommend-tools carries an inline graphify-only
# PreToolUse nudge. The applier must REPLACE it, not leave two hooks racing to
# say the same thing — while leaving unrelated hooks untouched.
TMP_L=$(mktemp -d)
mkdir -p "$TMP_L/.claude"
cat > "$TMP_L/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "case $CMD in *grep*) [ -f graphify-out/graph.json ] && echo nudge ;; esac" }
        ]
      }
    ],
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [{ "type": "command", "command": "unrelated-hook.sh" }] }
    ]
  },
  "permissions": { "allow": ["Bash(graphify *)"] }
}
JSON
"$AIKIT/bin/apply-search-delegation-hook.sh" "$TMP_L" >/dev/null
assert "legacy graphify nudge removed, not stacked" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_L/.claude/settings.json\"))
pre = d[\"hooks\"][\"PreToolUse\"]
assert len(pre) == 1, f\"expected 1 PreToolUse entry, got {len(pre)}\"
cmds = [h[\"command\"] for b in pre for h in b[\"hooks\"]]
assert not any(\"graphify-out/graph.json\" in c for c in cmds), cmds
assert any(\"search-delegation-check.sh\" in c for c in cmds), cmds
"'
assert "unrelated hooks survive" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_L/.claude/settings.json\"))
assert d[\"hooks\"][\"PostToolUse\"][0][\"hooks\"][0][\"command\"] == \"unrelated-hook.sh\"
assert d[\"permissions\"][\"allow\"] == [\"Bash(graphify *)\"]
"'
rm -rf "$TMP_L"

print_summary_and_exit
