#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/build-delegation-check.sh"

# The hook must fire exactly once per session, on the third DISTINCT file. If
# it fired on every edit it would be noise; if it counted repeat edits to one
# file it would fire on a single-file change — both are what these cases pin.
TMP_STATE=$(mktemp -d)
fire() {
  # fire <session_id> <tool_name> <file_path> -> prints additionalContext, empty if silent
  TMPDIR="$TMP_STATE" bash "$HOOK" <<<"{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":{\"file_path\":\"$3\"}}" |
    python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null || true
}

echo "=== build-delegation-check: fires once on the 3rd distinct file ==="
# section: build-delegation-check
OUT=$(fire s1 Edit /p/a.ts)
assert "1st distinct file silent" '[ -z "$OUT" ]'
OUT=$(fire s1 Write /p/b.ts)
assert "2nd distinct file silent" '[ -z "$OUT" ]'
OUT=$(fire s1 MultiEdit /p/c.ts)
assert "3rd distinct file fires" '[ -n "$OUT" ]'
assert "nudge names the builder subagent" 'grep -q "builder" <<<"$OUT"'
OUT=$(fire s1 Edit /p/d.ts)
assert "4th distinct file silent (fires once)" '[ -z "$OUT" ]'

OUT=$(fire s2 Edit /p/same.ts)
OUT=$(fire s2 Edit /p/same.ts)
OUT=$(fire s2 Edit /p/same.ts)
assert "same path 3x does not fire" '[ -z "$OUT" ]'

OUT=$(fire s3 Bash /p/a.ts)
OUT=$(fire s3 Bash /p/b.ts)
OUT=$(fire s3 Bash /p/c.ts)
assert "Bash never fires" '[ -z "$OUT" ]'

echo "=== build-delegation-check: state isolation + failure safety ==="
# section: build-delegation-isolation
OUT=$(fire s4 Edit /p/a.ts)
OUT=$(fire s4 Edit /p/b.ts)
OUT=$(fire s5 Edit /p/c.ts)
assert "different session_id does not share the count" '[ -z "$OUT" ]'
OUT=$(fire s4 Edit /p/c.ts)
assert "original session still fires on its own 3rd file" '[ -n "$OUT" ]'

set +e
JUNK_OUT=$(echo 'not json' | TMPDIR="$TMP_STATE" bash "$HOOK" 2>/dev/null)
JUNK_RC=$?
set -e
assert "malformed payload exits 0" '[ "$JUNK_RC" -eq 0 ]'
assert "malformed payload emits nothing" '[ -z "$JUNK_OUT" ]'

set +e
bash "$HOOK" </dev/null >/dev/null 2>&1
EMPTY_RC=$?
set -e
assert "empty payload exits clean" '[ "$EMPTY_RC" -eq 0 ]'

set +e
NOSESS_OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/p/a.ts"}}' | TMPDIR="$TMP_STATE" bash "$HOOK" 2>/dev/null)
NOSESS_RC=$?
set -e
assert "missing session_id is silent" '[ "$NOSESS_RC" -eq 0 ] && [ -z "$NOSESS_OUT" ]'

set +e
NOTMP_OUT=$(echo '{"session_id":"s6","tool_name":"Edit","tool_input":{"file_path":"/p/a.ts"}}' | TMPDIR=/nonexistent bash "$HOOK" 2>&1)
NOTMP_RC=$?
set -e
assert "unwritable temp dir exits 0 with no output on either stream" '[ "$NOTMP_RC" -eq 0 ] && [ -z "$NOTMP_OUT" ]'
rm -rf "$TMP_STATE"

echo "=== apply-build-delegation-hook ==="
# section: apply-build-delegation-hook
TMP_A=$(mktemp -d)
"$AIKIT/bin/apply-build-delegation-hook.sh" "$TMP_A" >/dev/null
assert "hook copied + executable" '[ -x "$TMP_A/.claude/hooks/build-delegation-check.sh" ]'
assert "PreToolUse wired with Edit|Write|MultiEdit matcher" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
pre = d[\"hooks\"][\"PreToolUse\"]
assert len(pre) == 1, pre
assert pre[0][\"matcher\"] == \"Edit|Write|MultiEdit\", pre[0]
"'

"$AIKIT/bin/apply-build-delegation-hook.sh" "$TMP_A" >/dev/null
assert "idempotent: second run does not stack" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
assert len(d[\"hooks\"][\"PreToolUse\"]) == 1
"'
rm -rf "$TMP_A"

echo "=== write-setup-marker records the branch ==="
# section: build-delegation-marker
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --build-delegation-hook=wired >/dev/null
assert "marker records build_delegation_hook" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"branches\"][\"build_delegation_hook\"])" "$TMP_M/.ai-kit-setup" | grep -q wired'
rm -rf "$TMP_M"

print_summary_and_exit
