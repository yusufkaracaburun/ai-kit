#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== skills-count ==="
# section: skills-count
SKILL_COUNT=$(find "$AIKIT/workflow/skills" -name SKILL.md | wc -l | tr -d ' ')
assert "23 skills" '[ "$SKILL_COUNT" -eq 23 ]'
assert "checkpoint skill exists" '[ -f "$AIKIT/workflow/skills/checkpoint/SKILL.md" ]'
assert "resume skill exists" '[ -f "$AIKIT/workflow/skills/resume/SKILL.md" ]'


echo "=== agents ==="
# section: agents
AGENT_COUNT=$(find "$AIKIT/workflow/agents" -name AGENT.md | wc -l | tr -d ' ')
assert "3 subagents present" '[ "$AGENT_COUNT" -eq 3 ]'
assert "explore exists" '[ -f "$AIKIT/workflow/agents/explore/AGENT.md" ]'
assert "reviewer exists" '[ -f "$AIKIT/workflow/agents/reviewer/AGENT.md" ]'
assert "qa-runner exists" '[ -f "$AIKIT/workflow/agents/qa-runner/AGENT.md" ]'
assert "explore frontmatter name" 'head -5 "$AIKIT/workflow/agents/explore/AGENT.md" | grep -q "^name: explore$"'
assert "explore frontmatter tools" 'head -5 "$AIKIT/workflow/agents/explore/AGENT.md" | grep -q "^tools:"'
assert "reviewer frontmatter name" 'head -5 "$AIKIT/workflow/agents/reviewer/AGENT.md" | grep -q "^name: reviewer$"'
assert "qa-runner frontmatter name" 'head -5 "$AIKIT/workflow/agents/qa-runner/AGENT.md" | grep -q "^name: qa-runner$"'
assert "qa-runner frontmatter tools" 'head -5 "$AIKIT/workflow/agents/qa-runner/AGENT.md" | grep -q "^tools:"'


echo "=== slash-commands ==="
# section: slash-commands
COMMAND_COUNT=$(find "$AIKIT/workflow/commands" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
assert "7 slash commands present" '[ "$COMMAND_COUNT" -eq 7 ]'
for cmd in doctor which status no-globals upgrade next; do
  assert "$cmd command exists"     "[ -f \"$AIKIT/workflow/commands/$cmd.md\" ]"
  assert "$cmd has description"    "head -6 \"$AIKIT/workflow/commands/$cmd.md\" | grep -q '^description:'"
  assert "$cmd has allowed-tools"  "head -6 \"$AIKIT/workflow/commands/$cmd.md\" | grep -q '^allowed-tools:'"
done


echo "=== review-skill-delegation ==="
# section: review-skill-delegation
assert "review skill mentions reviewer" 'grep -q "reviewer" "$AIKIT/workflow/skills/review/SKILL.md"'
assert "review skill mentions inline fallback" 'grep -q "Cursor / hosts without subagents" "$AIKIT/workflow/skills/review/SKILL.md"'
# The four migrated skills (#3) each carry a Run mode block + name their subagent.
for s in qa diagnose to-issues improve-codebase-architecture; do
  assert "$s skill has a Run mode block" 'grep -q "^## Run mode" "$AIKIT/workflow/skills/'"$s"'/SKILL.md"'
done
assert "qa skill delegates to qa-runner" 'grep -q "qa-runner" "$AIKIT/workflow/skills/qa/SKILL.md"'
assert "diagnose skill delegates to explore" 'grep -q "explore" "$AIKIT/workflow/skills/diagnose/SKILL.md"'
assert "to-issues skill delegates to explore" 'grep -q "explore" "$AIKIT/workflow/skills/to-issues/SKILL.md"'
assert "improve-arch skill delegates to explore" 'grep -q "explore" "$AIKIT/workflow/skills/improve-codebase-architecture/SKILL.md"'
assert "improve-arch skill dropped the generic Explore subagent" '! grep -q "subagent_type=Explore" "$AIKIT/workflow/skills/improve-codebase-architecture/SKILL.md"'


echo "=== plugin-manifest ==="
# section: plugin-manifest
PLUGIN_JSON="$AIKIT/workflow/.claude-plugin/plugin.json"
assert "plugin.json exists" '[ -f "$PLUGIN_JSON" ]'
assert "plugin.json is valid JSON" 'python3 -c "import json; json.load(open(\"$PLUGIN_JSON\"))"'
assert "plugin.json name is ai" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d[\"name\"]==\"ai\""'
assert "plugin.json has description" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d.get(\"description\")"'
assert "plugin.json has version" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d.get(\"version\")"'

# The marketplace catalog moved to the standalone yusufkaracaburun/marketplace
# repo on 2026-05-23 (closes #9). The in-repo `.claude-plugin/marketplace.json`
# must NOT come back — its presence would resurrect the legacy install path.
assert "in-repo marketplace.json is removed" '[ ! -f "$AIKIT/.claude-plugin/marketplace.json" ]'
assert "no .claude-plugin/ directory at repo root" '[ ! -d "$AIKIT/.claude-plugin" ]'

# plugin.json:version equals VERSION.
assert "VERSION/plugin.json version equality" \
  'bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1'


echo "=== sync-plugin-version-drift ==="
# section: sync-plugin-version-drift
# sync-plugin-version.sh stamps drift away.
TMP_PLUGIN_CHECK=$(mktemp -d)
cp "$PLUGIN_JSON" "$TMP_PLUGIN_CHECK/plugin.json"
# Deliberately corrupt the manifest version, verify --check spots it, then restore.
python3 -c "
import json
d=json.load(open('$PLUGIN_JSON'))
d['version']='0.0.0-drift'
json.dump(d, open('$PLUGIN_JSON','w'), indent=2)
open('$PLUGIN_JSON','a').write('\n')
"
set +e
bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1
SYNC_DRIFT_EXIT=$?
set -e
assert "sync-plugin-version --check detects drift" '[ "$SYNC_DRIFT_EXIT" -eq 1 ]'
bash "$AIKIT/bin/sync-plugin-version.sh" >/dev/null
bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1
SYNC_STAMP_EXIT=$?
assert "sync-plugin-version stamps drift away" '[ "$SYNC_STAMP_EXIT" -eq 0 ]'
rm -rf "$TMP_PLUGIN_CHECK"


echo "=== sync-plugin-hooks-bundled-hook-scripts- ==="
# section: sync-plugin-hooks-bundled-hook-scripts-
BUNDLED_POST="$AIKIT/workflow/hooks/post-skill-log.sh"
BUNDLED_LOG="$AIKIT/workflow/hooks/log-skill.sh"
BUNDLED_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "bundled post-skill-log.sh exists + executable" '[ -x "$BUNDLED_POST" ]'
assert "bundled log-skill.sh exists + executable" '[ -x "$BUNDLED_LOG" ]'
assert "bundled hooks.json exists" '[ -f "$BUNDLED_JSON" ]'
assert "hooks.json is valid JSON" 'python3 -c "import json; json.load(open(\"$BUNDLED_JSON\"))"'
assert "hooks.json has PostToolUse Skill matcher" 'python3 -c "
import json
d=json.load(open(\"$BUNDLED_JSON\"))
e=d[\"hooks\"][\"PostToolUse\"][0]
assert e[\"matcher\"]==\"^Skill\$\"
assert e[\"hooks\"][0][\"command\"]==\"\${CLAUDE_PLUGIN_ROOT}/hooks/post-skill-log.sh\"
"'
assert "bundled hook byte-identical to bin/ source" 'cmp -s "$AIKIT/bin/hooks/post-skill-log.sh" "$BUNDLED_POST"'
assert "bundled log-skill byte-identical to bin/ source" 'cmp -s "$AIKIT/bin/log-skill.sh" "$BUNDLED_LOG"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'
assert "sync-plugin-bin --check clean" 'bash "$AIKIT/bin/sync-plugin-bin.sh" --check >/dev/null 2>&1'
assert "workflow/bin/ai-kit-doctor.sh exists" '[ -x "$AIKIT/workflow/bin/ai-kit-doctor.sh" ]'
assert "plugin commands use CLAUDE_PLUGIN_ROOT" '! grep -lE "AI_KIT_ROOT.*\\\$HOME/\\.config/ai-kit/root.*}/bin/" "$AIKIT/workflow/commands/"*.md'

# Drift detection round-trip: mutate, --check fails, re-stamp, --check passes.
TMP_HOOK_BAK=$(mktemp -d)
cp "$BUNDLED_POST" "$TMP_HOOK_BAK/post-skill-log.sh"
echo "# tampered" >> "$BUNDLED_POST"
set +e
bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1
HOOK_DRIFT_EXIT=$?
set -e
assert "sync-plugin-hooks --check detects drift" '[ "$HOOK_DRIFT_EXIT" -eq 1 ]'
bash "$AIKIT/bin/sync-plugin-hooks.sh" >/dev/null
assert "sync-plugin-hooks stamps drift away" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'
rm -rf "$TMP_HOOK_BAK"


echo "=== VERSION ==="
# section: VERSION
assert "VERSION file" '[ -f "$AIKIT/VERSION" ]'


echo "=== eval-golden ==="
# section: eval-golden
# Each golden must satisfy its own rubric — catches drift where you weaken
# either the rubric or the golden without keeping them in sync.
if "$AIKIT/bin/eval-golden.sh" --validate-all > /tmp/eval-golden.out 2>&1; then
  GOLDEN_OK=true
else
  GOLDEN_OK=false
  echo "  (eval-golden.sh failures — see /tmp/eval-golden.out)"
  tail -20 /tmp/eval-golden.out
fi
assert "all goldens satisfy own rubric" '[ "$GOLDEN_OK" = true ]'

# A deliberately bad response must FAIL several checks — sanity for the
# rubric runner itself (catches the runner silently passing everything).
TMP_BAD_RESP=$(mktemp)
cat > "$TMP_BAD_RESP" <<'BADRESP'
---
id: cart-checkout
---

# Trivial response, hits none of the structural checks.

Some words here.
BADRESP
set +e
"$AIKIT/bin/eval-golden.sh" tdd cart-checkout "$TMP_BAD_RESP" > /tmp/eval-golden-bad.out 2>&1
BAD_EXIT=$?
set -e
assert "bad response fails (exit 1)" '[ "$BAD_EXIT" -eq 1 ]'
assert "bad response reports failed checks" 'grep -q "FAIL" /tmp/eval-golden-bad.out'
rm -f "$TMP_BAD_RESP"

# Coverage: each priority skill (to-prd, tdd, ship) has a golden.
for prio in to-prd tdd ship; do
  assert "golden exists: $prio" '[ -f "$AIKIT/tests/eval/goldens/$prio"/*.md ] || ls "$AIKIT/tests/eval/goldens/$prio"/*.md >/dev/null 2>&1'
done


echo "=== eval-structure ==="
# section: eval-structure
if "$AIKIT/tests/bin/eval-structure.sh" > /tmp/eval-structure.out 2>&1; then
  STRUCT_OK=true
else
  STRUCT_OK=false
  echo "  (eval-structure.sh failures — see /tmp/eval-structure.out)"
  tail -20 /tmp/eval-structure.out
fi
assert "eval-structure clean" '[ "$STRUCT_OK" = true ]'


print_summary_and_exit
