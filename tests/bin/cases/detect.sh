#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== detect-package-manager ==="
# section: detect-package-manager
TMP_PM=$(mktemp -d)
echo '{"name":"t"}' > "$TMP_PM/package.json"
echo "lockfileVersion: 5" > "$TMP_PM/pnpm-lock.yaml"
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/detect-package-manager.sh"
detect_package_manager "$TMP_PM"
assert "pnpm detected" '[ "$PM_NAME" = "pnpm" ]'
assert "pnpm install" '[ "$INSTALL_CMD" = "pnpm install" ]'
rm -rf "$TMP_PM"

TMP_COMP=$(mktemp -d)
echo '{}' > "$TMP_COMP/composer.json"
detect_package_manager "$TMP_COMP"
assert "composer detected" '[ "$PM_NAME" = "composer" ]'
rm -rf "$TMP_COMP"


echo "=== detect-architecture ==="
# section: detect-architecture
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/detect-lib.sh"

detect_architecture "$AIKIT/tests/fixtures/architecture-laravel"
assert "laravel FE inertia" '[ "$ARCH_FE" = "laravel-inertia" ]'
assert "laravel BE default" '[ "$ARCH_BE" = "laravel-default" ]'
assert "laravel recommend document" '[ "$ARCH_RECOMMENDATION" = "document-existing" ]'

detect_architecture "$AIKIT/tests/fixtures/architecture-fsd"
assert "fsd feature-folders" '[ "$ARCH_FE" = "feature-folders" ]'


echo "=== detect-agent-stack ==="
# section: detect-agent-stack
detect_agent_stack "$AIKIT/tests/fixtures/brownfield-custom-skills" "$AIKIT"
assert "custom skill detected" '[[ " ${AGENT_STACK_CURSOR_SKILLS_CUSTOM[*]} " == *" my-custom-skill "* ]]'
assert "recommend brownfield" '[ "$AGENT_STACK_RECOMMENDATION" = "brownfield" ]'
assert "needs doc" '[ "$AGENT_STACK_NEEDS_DOC" = true ]'

JSON_BF="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/brownfield-custom-skills" --json)"
assert "json agent_stack" 'echo "$JSON_BF" | grep -q "\"recommendation\": \"brownfield\""'
assert "json custom skill" 'echo "$JSON_BF" | grep -q "my-custom-skill"'

detect_agent_stack "$AIKIT/tests/fixtures/brownfield-claude-mcp" "$AIKIT"
assert "claude .mcp.json detected" '[[ " ${AGENT_STACK_MCP[*]} " == *" .mcp.json "* ]]'
assert "claude mcp recommends brownfield" '[ "$AGENT_STACK_RECOMMENDATION" = "brownfield" ]'

TMP_MCP=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --with-mcp "$TMP_MCP"
assert "with-mcp creates mcp.json" '[ -f "$TMP_MCP/.cursor/mcp.json" ]'
assert "with-mcp template content" 'grep -q "ai-kit baseline MCP" "$TMP_MCP/.cursor/mcp.json"'
rm -rf "$TMP_MCP"

TMP_MCP_KEEP=$(mktemp -d)
mkdir -p "$TMP_MCP_KEEP/.cursor"
echo '{"existing":true}' > "$TMP_MCP_KEEP/.cursor/mcp.json"
"$AIKIT/bin/bootstrap-project.sh" --minimal --with-mcp "$TMP_MCP_KEEP" >/dev/null
assert "with-mcp preserves existing" 'grep -q "existing" "$TMP_MCP_KEEP/.cursor/mcp.json"'
rm -rf "$TMP_MCP_KEEP"


echo "=== detect-monorepo-detect-boost ==="
# section: detect-monorepo-detect-boost
detect_monorepo "$AIKIT/tests/fixtures/monorepo-laravel-boost"
assert "monorepo detected" '[ "$MONOREPO_DETECTED" = true ]'
assert "monorepo lists 3 apps" '[ "${#MONOREPO_APPS[@]}" -eq 3 ]'
assert "monorepo includes backend" '[[ " ${MONOREPO_APPS[*]} " == *" backend "* ]]'

detect_monorepo "$AIKIT/tests/fixtures/architecture-laravel"
assert "single-app repo not flagged monorepo" '[ "$MONOREPO_DETECTED" = false ]'

detect_boost "$AIKIT/tests/fixtures/monorepo-laravel-boost"
assert "boost detected" '[ "$BOOST_DETECTED" = true ]'
assert "boost managed file is backend/AGENTS.md" '[[ " ${BOOST_MANAGED_FILES[*]} " == *" backend/AGENTS.md "* ]]'

detect_boost "$AIKIT/tests/fixtures/architecture-laravel"
assert "no boost in plain laravel fixture" '[ "$BOOST_DETECTED" = false ]'

JSON_MONO="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/monorepo-laravel-boost" --json)"
assert "json monorepo.detected true" 'echo "$JSON_MONO" | python3 -c "import json,sys; assert json.load(sys.stdin)[\"monorepo\"][\"detected\"] is True"'
assert "json monorepo lists backend" 'echo "$JSON_MONO" | python3 -c "import json,sys; assert \"backend\" in json.load(sys.stdin)[\"monorepo\"][\"apps\"]"'
assert "json boost.detected true" 'echo "$JSON_MONO" | python3 -c "import json,sys; assert json.load(sys.stdin)[\"boost\"][\"detected\"] is True"'
assert "json boost managed file" 'echo "$JSON_MONO" | python3 -c "import json,sys; assert \"backend/AGENTS.md\" in json.load(sys.stdin)[\"boost\"][\"managed_files\"]"'
assert "json still valid overall" 'echo "$JSON_MONO" | python3 -c "import json,sys; json.load(sys.stdin)"'


echo "=== detect-bootstrap-state ==="
# section: detect-bootstrap-state
TMP_BS_MERGE=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --merge-skills "$TMP_BS_MERGE" >/dev/null
detect_bootstrap_state "$TMP_BS_MERGE"
assert "merge-skills detected complete" '[ "$BOOTSTRAP_STATE" = "complete" ]'
assert "merge-skills no missing dirs" '[ "${#BOOTSTRAP_MISSING[@]}" -eq 0 ]'
rm -rf "$TMP_BS_MERGE"

TMP_BS_LINK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --link-all "$TMP_BS_LINK" >/dev/null
detect_bootstrap_state "$TMP_BS_LINK"
assert "link-all detected complete" '[ "$BOOTSTRAP_STATE" = "complete" ]'
rm -rf "$TMP_BS_LINK"

TMP_BS_EMPTY=$(mktemp -d)
detect_bootstrap_state "$TMP_BS_EMPTY"
assert "empty dir detected missing" '[ "$BOOTSTRAP_STATE" = "missing" ]'
assert "missing list mentions .claude/skills" '[[ " ${BOOTSTRAP_MISSING[*]} " == *" .claude/skills "* ]]'
rm -rf "$TMP_BS_EMPTY"


echo "=== detect-tooling-json ==="
# section: detect-tooling-json
JSON_OUT="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/architecture-laravel" --json)"
assert "json has architecture.frontend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-inertia\""'
assert "json has architecture.backend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-default\""'


print_summary_and_exit
