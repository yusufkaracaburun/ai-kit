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
# Older markers carry no build_delegation_hook field; the hook fires for them.
PROJ=$(mktemp -d)
echo '{"branches": {}}' > "$PROJ/.ai-kit-setup"
fire() {
  # fire <session_id> <tool_name> <file_path> [project] -> prints additionalContext, empty if silent
  CLAUDE_PROJECT_DIR="${4:-$PROJ}" TMPDIR="$TMP_STATE" bash "$HOOK" <<<"{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":{\"file_path\":\"$3\"}}" |
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
JUNK_OUT=$(echo 'not json' | CLAUDE_PROJECT_DIR="$PROJ" TMPDIR="$TMP_STATE" bash "$HOOK" 2>/dev/null)
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
NOSESS_OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/p/a.ts"}}' | CLAUDE_PROJECT_DIR="$PROJ" TMPDIR="$TMP_STATE" bash "$HOOK" 2>/dev/null)
NOSESS_RC=$?
set -e
assert "missing session_id is silent" '[ "$NOSESS_RC" -eq 0 ] && [ -z "$NOSESS_OUT" ]'

set +e
NOTMP_OUT=$(echo '{"session_id":"s6","tool_name":"Edit","tool_input":{"file_path":"/p/a.ts"}}' | CLAUDE_PROJECT_DIR="$PROJ" TMPDIR=/nonexistent bash "$HOOK" 2>&1)
NOTMP_RC=$?
set -e
assert "unwritable temp dir exits 0 with no output on either stream" '[ "$NOTMP_RC" -eq 0 ] && [ -z "$NOTMP_OUT" ]'
rm -rf "$TMP_STATE"

echo "=== build-delegation-check: marker gate ==="
# section: build-delegation-gate
TMP_STATE=$(mktemp -d)
NOMARK=$(mktemp -d)
for f in a b c; do OUT=$(fire g1 Edit "/g/$f.ts" "$NOMARK"); done
assert "silent without .ai-kit-setup" '[ -z "$OUT" ]'
SKIP=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$SKIP" --build-delegation-hook=skipped >/dev/null
for f in a b c; do OUT=$(fire g2 Edit "/g/$f.ts" "$SKIP"); done
assert "silent when marker says skipped" '[ -z "$OUT" ]'

echo "=== build-delegation-check: plugin delivery ==="
# section: build-delegation-plugin
assert "hooks.json registers build-delegation on PreToolUse(Edit|Write|MultiEdit)" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
b = [b for b in d[\"hooks\"][\"PreToolUse\"] if any(h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/hooks/build-delegation-check.sh\" for h in b[\"hooks\"])]
assert len(b) == 1 and b[0][\"matcher\"] == \"Edit|Write|MultiEdit\", b
"'
rm -rf "$TMP_STATE" "$NOMARK" "$SKIP" "$PROJ"

echo "=== write-setup-marker records the branch ==="
# section: build-delegation-marker
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --build-delegation-hook=wired >/dev/null
assert "marker records build_delegation_hook" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"branches\"][\"build_delegation_hook\"])" "$TMP_M/.ai-kit-setup" | grep -q wired'
rm -rf "$TMP_M"

print_summary_and_exit
