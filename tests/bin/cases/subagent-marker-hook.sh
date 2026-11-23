#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/subagent-marker.sh"
TMP_S=$(mktemp -d)
REPO="$TMP_S/repo"
git init -q "$REPO"
MARKS="$REPO/.git/ai-kit/subagents"

fire() {
  # fire <event> <agent_type> <agent_id> [cwd] -> hook stdout
  python3 -c 'import json,sys; print(json.dumps({"hook_event_name": sys.argv[1], "agent_type": sys.argv[2], "agent_id": sys.argv[3], "cwd": sys.argv[4]}))' \
    "$1" "$2" "$3" "${4:-$REPO/sub}" | bash "$HOOK"
}
mkdir -p "$REPO/sub"

echo "=== subagent-marker: start ==="
# section: subagent-marker-start
OUT=$(fire SubagentStart builder b1)
assert "builder start creates marker" '[ -f "$MARKS/b1" ] && [ ! -s "$MARKS/b1" ]'
assert "start prints nothing" '[ -z "$OUT" ]'
fire SubagentStart ai:designer d1 >/dev/null
assert "ai:designer start creates marker" '[ -f "$MARKS/d1" ]'
fire SubagentStart Explore e1 >/dev/null
assert "explore start creates no marker" '[ ! -e "$MARKS/e1" ]'

echo "=== subagent-marker: stop ==="
# section: subagent-marker-stop
OUT=$(fire SubagentStop builder b1)
assert "stop removes its marker" '[ ! -e "$MARKS/b1" ]'
assert "stop keeps other markers" '[ -f "$MARKS/d1" ]'
assert "stop prints nothing" '[ -z "$OUT" ]'

echo "=== subagent-marker: linked worktree ==="
# section: subagent-marker-worktree
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$REPO" worktree add -q "$TMP_S/wt" 2>/dev/null
fire SubagentStart builder w1 "$TMP_S/wt" >/dev/null
assert "worktree start marks under the common dir" '[ -f "$MARKS/w1" ]'
fire SubagentStop builder w1 "$REPO" >/dev/null
assert "main-checkout stop removes the worktree marker" '[ ! -e "$MARKS/w1" ]'

echo "=== subagent-marker: failure safety ==="
# section: subagent-marker-safety
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1); EMPTY_RC=$?
BAD_OUT=$(bash "$HOOK" <<<'{not json' 2>&1); BAD_RC=$?
NOGIT="$TMP_S/nogit"; mkdir -p "$NOGIT"
NOGIT_OUT=$(fire SubagentStart builder n1 "$NOGIT" 2>&1); NOGIT_RC=$?
NOID_OUT=$(fire SubagentStart builder "" 2>&1); NOID_RC=$?
TRAV_OUT=$(fire SubagentStart builder "../../x" 2>&1); TRAV_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
assert "malformed payload exits 0 silent" '[ "$BAD_RC" -eq 0 ] && [ -z "$BAD_OUT" ]'
assert "outside git exits 0 silent, no file" '[ "$NOGIT_RC" -eq 0 ] && [ -z "$NOGIT_OUT" ] && [ ! -e "$NOGIT/.git" ]'
assert "missing agent_id exits 0 silent" '[ "$NOID_RC" -eq 0 ] && [ -z "$NOID_OUT" ] && [ "$(ls "$MARKS")" = d1 ]'
assert "agent_id with a slash writes nothing" '[ "$TRAV_RC" -eq 0 ] && [ -z "$TRAV_OUT" ] && [ ! -e "$REPO/.git/x" ]'
command rm -rf "$TMP_S"

echo "=== subagent-marker: plugin delivery ==="
# section: subagent-marker-plugin
for ev in SubagentStart SubagentStop; do
  assert "hooks.json registers subagent-marker on $ev" \
    'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"$ev\"] for h in b[\"hooks\"]]
assert \"\${CLAUDE_PLUGIN_ROOT}/bin/hooks/subagent-marker.sh\" in cmds, cmds
"'
done

echo "=== subagent-marker: stop-gate recipe ==="
# section: subagent-marker-recipe
assert "test-suite-stop-gate carries requirement (5)" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/standards/external/hooks-patterns.json\"))
v = [p for p in d[\"recommendations\"] if p[\"name\"] == \"test-suite-stop-gate\"][0][\"value\"]
assert \"(5)\" in v and \"test gate skipped: builder active\" in v and \"rev-parse --path-format=absolute --git-common-dir)/ai-kit/subagents/\" in v and \"2 hours\" in v, v
"'

print_summary_and_exit
