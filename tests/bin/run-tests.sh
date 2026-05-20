#!/usr/bin/env bash
# Regression tests for ai-kit bin scripts.
set -euo pipefail

AIKIT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert() {
  if eval "$2"; then
    echo "  OK: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== detect-package-manager ==="
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

echo ""
echo "=== detect_architecture ==="
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/detect-lib.sh"

detect_architecture "$AIKIT/tests/fixtures/architecture-laravel"
assert "laravel FE inertia" '[ "$ARCH_FE" = "laravel-inertia" ]'
assert "laravel BE default" '[ "$ARCH_BE" = "laravel-default" ]'
assert "laravel recommend document" '[ "$ARCH_RECOMMENDATION" = "document-existing" ]'

detect_architecture "$AIKIT/tests/fixtures/architecture-fsd"
assert "fsd feature-folders" '[ "$ARCH_FE" = "feature-folders" ]'

echo ""
echo "=== detect_agent_stack ==="
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

echo ""
echo "=== detect-tooling --json ==="
JSON_OUT="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/architecture-laravel" --json)"
assert "json has architecture.frontend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-inertia\""'
assert "json has architecture.backend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-default\""'

echo ""
echo "=== bootstrap ==="
TMP_BOOT=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_BOOT"
assert "AGENTS.md" '[ -f "$TMP_BOOT/AGENTS.md" ]'
assert ".cursor/skills dir" '[ -d "$TMP_BOOT/.cursor/skills" ]'
assert "setup skill linked" '[ -L "$TMP_BOOT/.cursor/skills/setup" ] || [ -d "$TMP_BOOT/.cursor/skills/setup" ]'
assert "ai-kit.mdc" '[ -f "$TMP_BOOT/.cursor/rules/ai-kit.mdc" ]'
assert "no docker.md yet" '[ ! -f "$TMP_BOOT/docs/agents/docker.md" ]'
rm -rf "$TMP_BOOT"

TMP_LINK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --link-all "$TMP_LINK"
assert "link-all symlink" '[ -L "$TMP_LINK/.cursor/skills" ]'
rm -rf "$TMP_LINK"

TMP_MERGE=$(mktemp -d)
cp -R "$AIKIT/tests/fixtures/brownfield-custom-skills/.cursor" "$TMP_MERGE/"
"$AIKIT/bin/bootstrap-project.sh" --minimal --merge-skills "$TMP_MERGE"
assert "merge keeps custom skill" '[ -d "$TMP_MERGE/.cursor/skills/my-custom-skill" ] || [ -L "$TMP_MERGE/.cursor/skills/my-custom-skill" ]'
assert "merge adds setup" '[ -e "$TMP_MERGE/.cursor/skills/setup" ]'
rm -rf "$TMP_MERGE"

TMP_NO_SK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-skills "$TMP_NO_SK"
assert "no-skills AGENTS.md" '[ -f "$TMP_NO_SK/AGENTS.md" ]'
assert "no-skills skips .agents/skills" '[ ! -e "$TMP_NO_SK/.agents/skills" ]'
assert "no-skills skips .cursor/skills" '[ ! -e "$TMP_NO_SK/.cursor/skills" ]'
rm -rf "$TMP_NO_SK"

echo ""
echo "=== apply-docker ==="
TMP_D=$(mktemp -d)
mkdir -p "$TMP_D/docs/agents"
"$AIKIT/bin/apply-docker.sh" "$TMP_D" none
assert "docker none" '[ -f "$TMP_D/docs/agents/docker.md" ] && grep -q none "$TMP_D/.ai-kit-docker"'
"$AIKIT/bin/apply-docker.sh" "$TMP_D" existing
assert "docker existing" 'grep -q existing "$TMP_D/.ai-kit-docker"'
rm -rf "$TMP_D"

echo ""
echo "=== apply-sandcastle ==="
TMP_SC=$(mktemp -d)
echo '{"name":"t"}' > "$TMP_SC/package.json"
echo "lockfileVersion: 5" > "$TMP_SC/pnpm-lock.yaml"
"$AIKIT/bin/apply-sandcastle.sh" "$TMP_SC"
assert "sandcastle dir" '[ -d "$TMP_SC/.sandcastle" ]'
assert "pnpm in main.mts" 'grep -q "pnpm install" "$TMP_SC/.sandcastle/main.mts"'
assert "no placeholder" '! grep -q "{{INSTALL_CMD}}" "$TMP_SC/.sandcastle/main.mts"'
rm -rf "$TMP_SC"

echo ""
echo "=== write-setup-marker ==="
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --setup-mode=solo-both --tier=minimal --architecture=skipped --docker=skipped --tracker=skipped --workflow=skipped --sandcastle=false
assert "marker exists" '[ -f "$TMP_M/.ai-kit-setup" ]'
assert "setup_mode solo-both" 'grep -q "\"setup_mode\": \"solo-both\"" "$TMP_M/.ai-kit-setup"'
assert "tier minimal" 'grep -q "\"setup_tier\": \"minimal\"" "$TMP_M/.ai-kit-setup"'
assert "version 1.0.0" 'grep -q "\"ai_kit_version\": \"1.0.0\"" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --architecture=skipped
assert "architecture merge skip" 'grep -q "\"architecture\": \"skipped\"" "$TMP_M/.ai-kit-setup"'
rm -rf "$TMP_M"

echo ""
echo "=== verify-setup minimal ==="
TMP_MIN=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_MIN"
mkdir -p "$TMP_MIN/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_MIN/docs/agents/"
sed -i '' '/Filled by \/setup/d' "$TMP_MIN/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/setup/d' "$TMP_MIN/docs/agents/dev-environment.md"
printf '\n| Tool | Documentation |\n| ---- | ------------- |\n| nx | https://nx.dev |\n' >> "$TMP_MIN/docs/agents/dev-environment.md"
"$AIKIT/bin/write-setup-marker.sh" "$TMP_MIN" --setup-mode=solo-both --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
if "$AIKIT/bin/verify-setup.sh" "$TMP_MIN" --strict --minimal >/dev/null 2>&1; then
  assert "verify minimal tier passes" true
else
  assert "verify minimal tier passes" false
fi
rm -rf "$TMP_MIN"

echo ""
echo "=== verify-setup ==="
TMP_V=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_V"
mkdir -p "$TMP_V/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_V/docs/agents/"
sed -i '' '/Filled by \/setup/d' "$TMP_V/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/setup/d' "$TMP_V/docs/agents/dev-environment.md"
printf '\n| Tool | Documentation |\n| ---- | ------------- |\n| ai-kit | https://github.com |\n' >> "$TMP_V/docs/agents/dev-environment.md"
cp "$AIKIT/context/templates/docs/agents/issue-tracker-github.md" "$TMP_V/docs/agents/issue-tracker.md"
cp "$AIKIT/context/templates/docs/agents/triage-labels.md" "$TMP_V/docs/agents/"
cp "$AIKIT/context/templates/docs/agents/domain.md" "$TMP_V/docs/agents/"
cp "$AIKIT/context/templates/docs/agents/workflow.md" "$TMP_V/docs/agents/"
"$AIKIT/bin/apply-docker.sh" "$TMP_V" none
"$AIKIT/bin/write-setup-marker.sh" "$TMP_V" --setup-mode=solo-both --tier=full --architecture=skipped --docker=none --tracker=github --workflow=informal --sandcastle=false
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" >/dev/null 2>&1; then
  assert "verify skipped arch passes" true
else
  assert "verify skipped arch passes" false
fi
"$AIKIT/bin/write-setup-marker.sh" "$TMP_V" --architecture=documented
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" >/dev/null 2>&1; then
  assert "verify fails without architecture.md" false
else
  assert "verify fails without architecture.md" true
fi
cp "$AIKIT/context/templates/docs/agents/architecture.md" "$TMP_V/docs/agents/"
sed -i '' 's/\[e.g. follow existing layout | co-located components | feature folders | FSD-like | pages\/routes\]/Feature folders (detected)/' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[e.g. follow existing layout | co-located components | feature folders | FSD-like | pages\/routes\]/Feature folders (detected)/' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[key paths, e.g. src\/features\/, app\/pages\/\]/src\/features\//' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[key paths, e.g. src\/features\/, app\/pages\/\]/src\/features\//' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[e.g. framework defaults | layered | actions | ports-adapters | modular monolith\]/Laravel MVC/' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[e.g. framework defaults | layered | actions | ports-adapters | modular monolith\]/Laravel MVC/' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[key paths, e.g. app\/Actions\/, src\/Domain\/\]/app\/Http\/Controllers\//' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[key paths, e.g. app\/Actions\/, src\/Domain\/\]/app\/Http\/Controllers\//' "$TMP_V/docs/agents/architecture.md"
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" --strict >/dev/null 2>&1; then
  assert "verify strict with filled architecture" true
else
  assert "verify strict with filled architecture" false
fi
rm -rf "$TMP_V"

echo ""
echo "=== agents-patch ==="
TMP_P=$(mktemp -d)
cp "$AIKIT/context/templates/AGENTS.md.template" "$TMP_P/AGENTS.md"
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/agents-patch.sh"
patch_agents_docker_section "$TMP_P"
assert "docker section patched" 'grep -q "### Docker" "$TMP_P/AGENTS.md"'
patch_agents_docker_section "$TMP_P"
assert "idempotent patch" '[ "$(grep -c "### Docker" "$TMP_P/AGENTS.md")" -eq 1 ]'
rm -rf "$TMP_P"

echo ""
echo "=== ai-kit-root ==="
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/ai-kit-root.sh"
ROOT_SCRIPT="$(resolve_ai_kit_root "$AIKIT/bin")"
assert "resolves from script path" '[ "$ROOT_SCRIPT" = "$AIKIT" ]'

TMP_HOME=$(mktemp -d)
export AI_KIT_ROOT=""
HOME="$TMP_HOME" write_ai_kit_root_config "$AIKIT"
ROOT_CFG="$(HOME="$TMP_HOME" resolve_ai_kit_root "")"
assert "resolves from config file" '[ "$ROOT_CFG" = "$AIKIT" ]'

export AI_KIT_ROOT="$AIKIT"
ROOT_ENV="$(resolve_ai_kit_root "")"
assert "resolves from AI_KIT_ROOT env" '[ "$ROOT_ENV" = "$AIKIT" ]'
unset AI_KIT_ROOT
rm -rf "$TMP_HOME"

CLI_OUT="$("$AIKIT/bin/ai-kit-root.sh")"
assert "ai-kit-root.sh CLI" '[ "$CLI_OUT" = "$AIKIT" ]'

echo ""
echo "=== skills count ==="
SKILL_COUNT=$(find "$AIKIT/workflow/skills" -name SKILL.md | wc -l | tr -d ' ')
assert "16 skills" '[ "$SKILL_COUNT" -eq 16 ]'

echo ""
echo "=== VERSION ==="
assert "VERSION file" '[ -f "$AIKIT/VERSION" ] && grep -q "1.0.0" "$AIKIT/VERSION"'

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All $PASS tests passed."
  exit 0
else
  echo "$FAIL failed, $PASS passed."
  exit 1
fi
