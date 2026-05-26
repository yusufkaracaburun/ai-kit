#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== count-primitives.sh ==="

# JSON mode emits all four keys.
JSON="$("$AIKIT/bin/count-primitives.sh")"
assert "JSON has skills key" 'echo "$JSON" | grep -q "\"skills\":"'
assert "JSON has commands key" 'echo "$JSON" | grep -q "\"commands\":"'
assert "JSON has rules key" 'echo "$JSON" | grep -q "\"rules\":"'
assert "JSON has subagents key" 'echo "$JSON" | grep -q "\"subagents\":"'

# Numbers match filesystem reality (delegated to count-primitives but
# double-checked here so a regression in the script itself is caught).
SKILLS_ACTUAL="$(find "$AIKIT/workflow/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
SKILLS_REPORTED="$(echo "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["skills"])')"
assert "JSON skills matches find" '[ "$SKILLS_ACTUAL" = "$SKILLS_REPORTED" ]'

CMDS_ACTUAL="$(find "$AIKIT/workflow/commands" -mindepth 1 -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
CMDS_REPORTED="$(echo "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["commands"])')"
assert "JSON commands matches find" '[ "$CMDS_ACTUAL" = "$CMDS_REPORTED" ]'

RULES_ACTUAL="$(find "$AIKIT/standards/rules" -mindepth 1 -maxdepth 1 -name '*.mini.md' | wc -l | tr -d ' ')"
RULES_REPORTED="$(echo "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["rules"])')"
assert "JSON rules matches find" '[ "$RULES_ACTUAL" = "$RULES_REPORTED" ]'

# --human one-liner shape.
HUMAN="$("$AIKIT/bin/count-primitives.sh" --human)"
assert "human says 'skills'" 'echo "$HUMAN" | grep -q "skills"'
assert "human says 'commands'" 'echo "$HUMAN" | grep -q "commands"'
assert "human says 'rules'" 'echo "$HUMAN" | grep -q "rules"'

# --check passes against current tree (drift-free baseline).
CHECK_OUT="$("$AIKIT/bin/count-primitives.sh" --check 2>&1)"
CHECK_RC=$?
assert "--check exits 0 on drift-free tree" '[ "$CHECK_RC" -eq 0 ]'
assert "--check says OK on drift-free tree" 'echo "$CHECK_OUT" | grep -q "OK"'

# Synthetic-drift fixture: copy plugin.json to tmp with a wrong skill count
# and assert the checker spots it. We can't tamper the real file without
# breaking other tests, so test the regex+substitution logic in isolation
# via the script's own grep-OR-fail path.
TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT
mkdir -p "$TMPDIR_RUN/workflow/.claude-plugin"
echo '{"description":"99 skills, 3 subagents, 99 slash commands, 99 canonical rules"}' \
  > "$TMPDIR_RUN/workflow/.claude-plugin/plugin.json"
cp -r "$AIKIT/workflow/skills" "$TMPDIR_RUN/workflow/"
cp -r "$AIKIT/workflow/agents" "$TMPDIR_RUN/workflow/"
cp -r "$AIKIT/workflow/commands" "$TMPDIR_RUN/workflow/"
mkdir -p "$TMPDIR_RUN/standards"
cp -r "$AIKIT/standards/rules" "$TMPDIR_RUN/standards/"

# Run the script with the synthetic root.
DRIFT_OUT="$(AI_KIT_ROOT="$TMPDIR_RUN" "$AIKIT/bin/count-primitives.sh" --check 2>&1 || true)"
assert "--check detects synthetic drift" 'echo "$DRIFT_OUT" | grep -q "DRIFT"'
assert "--check shows expected pattern" 'echo "$DRIFT_OUT" | grep -q "expected to contain"'

print_summary_and_exit
