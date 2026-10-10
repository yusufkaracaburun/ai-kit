#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/lead-guard.sh"

# Claims are written by the real claim script, so a change to its frontmatter
# format breaks this test instead of silently disarming the guard.
TMP_H=$(mktemp -d)
export HOME="$TMP_H"
bash "$AIKIT/bin/ai-kit-claim.sh" --session lead1 set role=lead >/dev/null
bash "$AIKIT/bin/ai-kit-claim.sh" --session build1 set role=build >/dev/null

fire() {
  # fire <session_id> <tool_name> <tool_input-json> [agent_id] -> deny reason, empty if silent
  local agent=""
  [ -n "${4:-}" ] && agent=",\"agent_id\":\"$4\""
  bash "$HOOK" <<<"{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":$3$agent}" |
    jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true
}
bash_cmd() { fire lead1 Bash "{\"command\":\"$1\"}"; }
fire_agent_json() {
  # fire_agent_json <agent_id json literal>: lead Edit with that raw agent_id value
  bash "$HOOK" <<<"{\"session_id\":\"lead1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/repo/src/a.ts\"},\"agent_id\":$1}" |
    grep -o '"deny"' || true
}
export TMPDIR="$TMP_H/tmpdir/"

echo "=== lead-guard: file edits ==="
# section: lead-guard-edits
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/a.ts"}')
assert "lead Edit on a repo file is denied" '[ -n "$OUT" ]'
assert "reason names lead-guard and the tool" 'grep -q "lead-guard" <<<"$OUT" && grep -q "Edit" <<<"$OUT"'
OUT=$(fire build1 Edit '{"file_path":"/repo/src/a.ts"}')
assert "role=build is silent" '[ -z "$OUT" ]'
OUT=$(fire noclaim Edit '{"file_path":"/repo/src/a.ts"}')
assert "no claim file is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write "{\"file_path\":\"$HOME/.claude/projects/p/memory/note.md\"}")
assert "Write under \$HOME/.claude is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/tmp/x"}')
assert "Write to /tmp is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/private/tmp/x"}')
assert "Write to /private/tmp is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write "{\"file_path\":\"${TMPDIR}memo.md\"}")
assert "Write under \$TMPDIR is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/repo/.agents/memory/project/note.md"}')
assert "Write under .agents/memory is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/repo/.planning/plan.md"}')
assert "Write under .planning is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/.agents/worktrees/w/src/a.ts"}')
assert "Edit of code in an .agents worktree is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/memory/cache.ts"}')
assert "Edit of src/memory code is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/Users/x/.claude/projects/p/memory/note.md"}')
assert "Edit under another user's .claude is denied" '[ -n "$OUT" ]'
assert "agent_id null counts as main thread" '[ -n "$(fire_agent_json null)" ]'
assert "agent_id empty counts as main thread" '[ -n "$(fire_agent_json "\"\"")" ]'
assert "agent_id set is a subagent" '[ -z "$(fire_agent_json "\"x\"")" ]'
OUT=$(fire lead1 NotebookEdit '{"notebook_path":"/repo/n.ipynb"}')
assert "NotebookEdit on a repo notebook is denied" '[ -n "$OUT" ]'

echo "=== lead-guard: Bash ==="
# section: lead-guard-bash
OUT=$(bash_cmd "git status")
assert "git status is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "git commit -m x")
assert "git commit is denied" '[ -n "$OUT" ] && grep -q "Bash" <<<"$OUT"'
OUT=$(bash_cmd "flutter test")
assert "flutter test is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "sed -n 1,5p f")
assert "sed -n is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "sed -i 's/a/b/' f")
assert "sed -i is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "cmd 2>/dev/null")
assert "2>/dev/null is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "cmd 2>&1 | grep x")
assert "2>&1 is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "echo x > f")
assert "redirect to a file is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "asc apps list")
assert "asc list is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "asc apps update --name y")
assert "asc update is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "gh pr view 12")
assert "gh pr view is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "gh pr create --fill")
assert "gh pr create is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "bash bin/ai-kit-claim.sh show")
assert "ai-kit-claim.sh is silent" '[ -z "$OUT" ]'

allow() { OUT=$(bash_cmd "$1"); assert "allow: $1" '[ -z "$OUT" ]'; }
deny() { OUT=$(bash_cmd "$1"); assert "deny: $1" '[ -n "$OUT" ]'; }
allow "ps -Ao args | grep -E 'pest|paratest|gradle' | grep -v grep"
allow "cat tests/Pest.php"
allow "git log -S kill"
allow "git stash list"
allow "git branch"
allow "git diff --stat"
allow "gh issue list"
allow "gh pr status"
allow "gh api repos/o/r/pulls"
allow "cat > \$TMPDIR/memo.md"
allow "cat > \${TMPDIR}memo.md"
allow "cat >> ${TMPDIR}memo.md"
allow "echo x > /tmp/x"
allow "echo x >> /private/tmp/x"
deny "./vendor/bin/pest"
deny "XDEBUG_MODE=off ./vendor/bin/pest --parallel"
deny "cd app && ./gradlew test"
deny "npx jest"
deny "kill 123"
deny "git stash"
deny "git stash pop"
deny "git clean -fd"
deny "git checkout -- src/a.ts"
deny "git branch -D old"
deny "git branch -d old"
deny "git add src/a.ts"
deny "rm notes.txt"
deny "composer install"
deny "composer update"
deny "composer require foo/bar"
deny "make"
deny "gh api -X POST repos/o/r/issues"
deny "gh api --method PATCH repos/o/r"
deny "gh pr comment 12 --body x"
deny "gh pr review 12 --approve"
deny "gh issue comment 3 --body x"
deny "echo x >> notes.md"

echo "=== lead-guard: design + browser ==="
# section: lead-guard-mcp
OUT=$(fire lead1 mcp__pencil__execute '{}')
assert "pencil execute is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 mcp__pencil__get_app_state '{}')
assert "pencil get_app_state is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 mcp__claude-in-chrome__computer '{}')
assert "chrome computer is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 mcp__claude-in-chrome__read_page '{}')
assert "chrome read_page is silent" '[ -z "$OUT" ]'

echo "=== lead-guard: failure safety ==="
# section: lead-guard-safety
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1)
EMPTY_RC=$?
JUNK_OUT=$(echo 'not json' | bash "$HOOK" 2>&1)
JUNK_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
assert "malformed payload exits 0 silent" '[ "$JUNK_RC" -eq 0 ] && [ -z "$JUNK_OUT" ]'
rm -rf "$TMP_H"

echo "=== lead-guard: plugin delivery ==="
# section: lead-guard-plugin
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "hooks.json registers lead-guard on PreToolUse for every guarded tool" \
  'python3 -c "
import json, re
d = json.load(open(\"$HOOKS_JSON\"))
b = [b for b in d[\"hooks\"][\"PreToolUse\"] if any(h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/hooks/lead-guard.sh\" for h in b[\"hooks\"])]
assert len(b) == 1, b
for t in [\"Edit\", \"Write\", \"MultiEdit\", \"NotebookEdit\", \"Bash\", \"mcp__pencil__execute\", \"mcp__claude-in-chrome__computer\"]:
    assert re.fullmatch(b[0][\"matcher\"], t), t
"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'

print_summary_and_exit
