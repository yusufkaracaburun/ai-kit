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
  # fire <project_dir> <payload_json> -> prints additionalContext, empty if silent
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
# Older markers carry no search_delegation_hook field; the hook fires for them.
echo '{"branches": {}}' > "$TMP_H/.ai-kit-setup"

OUT=$(fire "$TMP_H" '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ."}}')
assert "bash grep fires" '[ -n "$OUT" ]'

OUT=$(fire "$TMP_H" '{"tool_name":"Bash","tool_input":{"command":"rg pattern"}}')
assert "bash rg fires" '[ -n "$OUT" ]'

for c in "echo x | grep y" "grep -c foo path/file.md" "grep -nE 'a|b' wrangler.jsonc"; do
  OUT=$(fire "$TMP_H" "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$c")")
  assert "non-recursive grep silent: $c" '[ -z "$OUT" ]'
done

for c in "grep -rn foo src/" "grep -Rin foo ."; do
  OUT=$(fire "$TMP_H" "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$c")")
  assert "sweep fires: $c" '[ -n "$OUT" ]'
done

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

echo "=== search-delegation-check: marker gate ==="
# section: search-delegation-gate
SWEEP='{"tool_name":"Grep","tool_input":{"pattern":"x"}}'
NOMARK=$(mktemp -d)
OUT=$(fire "$NOMARK" "$SWEEP")
assert "silent without .ai-kit-setup" '[ -z "$OUT" ]'
SKIP=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$SKIP" --search-delegation-hook=skipped >/dev/null
OUT=$(fire "$SKIP" "$SWEEP")
assert "silent when marker says skipped" '[ -z "$OUT" ]'

echo "=== search-delegation-check: plugin delivery ==="
# section: search-delegation-plugin
assert "hooks.json registers search-delegation on PreToolUse(Bash|Grep|Glob)" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
b = [b for b in d[\"hooks\"][\"PreToolUse\"] if any(h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/hooks/search-delegation-check.sh\" for h in b[\"hooks\"])]
assert len(b) == 1 and b[0][\"matcher\"] == \"Bash|Grep|Glob\", b
"'
rm -rf "$NOMARK" "$SKIP"

print_summary_and_exit
