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

TMP_FLUTTER=$(mktemp -d)
printf 'name: t\ndependencies:\n  flutter:\n    sdk: flutter\n  provider: ^6.1.2\n' > "$TMP_FLUTTER/pubspec.yaml"
detect_package_manager "$TMP_FLUTTER"
assert "flutter pm detected" '[ "$PM_NAME" = "flutter" ]'
assert "flutter pub get" '[ "$INSTALL_CMD" = "flutter pub get" ]'
assert "has_dart true for flutter app" '[ "$HAS_DART" = true ]'
rm -rf "$TMP_FLUTTER"

TMP_DART=$(mktemp -d)
printf 'name: t\ndependencies:\n  http: ^1.2.2\n' > "$TMP_DART/pubspec.yaml"
detect_package_manager "$TMP_DART"
assert "pure dart pm detected" '[ "$PM_NAME" = "dart" ]'
assert "dart pub get" '[ "$INSTALL_CMD" = "dart pub get" ]'
rm -rf "$TMP_DART"


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


echo "=== detect-frameworks ==="
# section: detect-frameworks
TMP_FW=$(mktemp -d)
echo '{"dependencies":{"astro":"^5.0.0","astro-icon":"^1.0.0"}}' > "$TMP_FW/package.json"
detect_frameworks "$TMP_FW"
assert "astro detected" '[[ " ${FRAMEWORKS[*]} " == *" astro "* ]]'
assert "astro exactly once (astro-icon no match)" '[ "$(printf "%s\n" "${FRAMEWORKS[@]}" | grep -cx astro)" = "1" ]'
assert "astro docs url" '[ "$(docs_url_for astro)" = "https://docs.astro.build" ]'
rm -rf "$TMP_FW"

TMP_FLUTTER_FW=$(mktemp -d)
printf 'name: t\ndependencies:\n  flutter:\n    sdk: flutter\n  provider: ^6.1.2\n  get_it: ^8.0.0\n' > "$TMP_FLUTTER_FW/pubspec.yaml"
detect_frameworks "$TMP_FLUTTER_FW"
assert "flutter detected" '[[ " ${FRAMEWORKS[*]} " == *" flutter "* ]]'
assert "flutter docs url" '[ "$(docs_url_for flutter)" = "https://docs.flutter.dev" ]'
detect_dependencies "$TMP_FLUTTER_FW"
assert "pubspec deps include provider" 'echo "$DEPENDENCIES_JSON" | python3 -c "import json,sys; assert \"provider\" in json.load(sys.stdin)"'
assert "pubspec deps include get_it" 'echo "$DEPENDENCIES_JSON" | python3 -c "import json,sys; assert \"get_it\" in json.load(sys.stdin)"'
assert "pubspec deps exclude flutter sdk dep" 'echo "$DEPENDENCIES_JSON" | python3 -c "import json,sys; assert \"flutter\" not in json.load(sys.stdin)"'
rm -rf "$TMP_FLUTTER_FW"

TMP_DART_FW=$(mktemp -d)
printf 'name: t\ndependencies:\n  http: ^1.2.2\n' > "$TMP_DART_FW/pubspec.yaml"
detect_frameworks "$TMP_DART_FW"
assert "pure dart package not flagged flutter" '[ "${#FRAMEWORKS[@]}" -eq 0 ]'
rm -rf "$TMP_DART_FW"


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
assert "json has architecture.frontend" 'grep -q "\"detected\": \"laravel-inertia\"" <<<"$JSON_OUT"'
assert "json has architecture.backend" 'grep -q "\"detected\": \"laravel-default\"" <<<"$JSON_OUT"'
assert "json has_dart false for laravel fixture" 'echo "$JSON_OUT" | python3 -c "import json,sys; assert json.load(sys.stdin)[\"package_manager\"][\"has_dart\"] is False"'

TMP_JSON_FLUTTER=$(mktemp -d)
printf 'name: t\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$TMP_JSON_FLUTTER/pubspec.yaml"
JSON_FLUTTER="$("$AIKIT/bin/detect-tooling.sh" "$TMP_JSON_FLUTTER" --json)"
assert "json has_dart true for flutter repo" 'echo "$JSON_FLUTTER" | python3 -c "import json,sys; assert json.load(sys.stdin)[\"package_manager\"][\"has_dart\"] is True"'
assert "json frameworks include flutter" 'echo "$JSON_FLUTTER" | python3 -c "import json,sys; assert \"flutter\" in json.load(sys.stdin)[\"frameworks\"]"'
rm -rf "$TMP_JSON_FLUTTER"


echo "=== detect-deploy-shape ==="
# section: detect-deploy-shape
TMP_DEPLOY_UNK=$(mktemp -d)
detect_deploy_shape "$TMP_DEPLOY_UNK"
assert "empty repo → deploy_shape=unknown" '[ "$DEPLOY_SHAPE" = "unknown" ]'
assert "empty repo → coolify_detected=false" '[ "$DEPLOY_COOLIFY" = false ]'
rm -rf "$TMP_DEPLOY_UNK"

TMP_DEPLOY_SELF=$(mktemp -d)
echo "FROM alpine" > "$TMP_DEPLOY_SELF/Dockerfile"
echo "version: '3'" > "$TMP_DEPLOY_SELF/compose.yaml"
detect_deploy_shape "$TMP_DEPLOY_SELF"
assert "Dockerfile + compose → deploy_shape=self-host" '[ "$DEPLOY_SHAPE" = "self-host" ]'
rm -rf "$TMP_DEPLOY_SELF"

TMP_DEPLOY_DF_ONLY=$(mktemp -d)
echo "FROM alpine" > "$TMP_DEPLOY_DF_ONLY/Dockerfile"
detect_deploy_shape "$TMP_DEPLOY_DF_ONLY"
assert "Dockerfile-only → still unknown (needs compose or Coolify)" '[ "$DEPLOY_SHAPE" = "unknown" ]'
rm -rf "$TMP_DEPLOY_DF_ONLY"

TMP_DEPLOY_SLS=$(mktemp -d)
echo "{}" > "$TMP_DEPLOY_SLS/vercel.json"
detect_deploy_shape "$TMP_DEPLOY_SLS"
assert "vercel.json → deploy_shape=serverless" '[ "$DEPLOY_SHAPE" = "serverless" ]'
rm -rf "$TMP_DEPLOY_SLS"

TMP_DEPLOY_MIX=$(mktemp -d)
echo "FROM alpine" > "$TMP_DEPLOY_MIX/Dockerfile"
echo "version: '3'" > "$TMP_DEPLOY_MIX/compose.yaml"
echo "{}" > "$TMP_DEPLOY_MIX/vercel.json"
detect_deploy_shape "$TMP_DEPLOY_MIX"
assert "Dockerfile + compose + vercel.json → deploy_shape=mixed" '[ "$DEPLOY_SHAPE" = "mixed" ]'
rm -rf "$TMP_DEPLOY_MIX"

TMP_DEPLOY_C=$(mktemp -d)
mkdir "$TMP_DEPLOY_C/.coolify"
detect_deploy_shape "$TMP_DEPLOY_C"
assert ".coolify marker → coolify_detected=true" '[ "$DEPLOY_COOLIFY" = true ]'
assert ".coolify marker → deploy_shape=self-host (no Dockerfile needed)" '[ "$DEPLOY_SHAPE" = "self-host" ]'
rm -rf "$TMP_DEPLOY_C"

# JSON surface check
TMP_DEPLOY_JSON=$(mktemp -d)
echo "FROM alpine" > "$TMP_DEPLOY_JSON/Dockerfile"
echo "version: '3'" > "$TMP_DEPLOY_JSON/compose.yaml"
JSON_DEPLOY="$("$AIKIT/bin/detect-tooling.sh" "$TMP_DEPLOY_JSON" --json)"
assert "JSON output has deploy.shape=self-host" 'echo "$JSON_DEPLOY" | python3 -c "import json,sys; assert json.load(sys.stdin)[\"deploy\"][\"shape\"] == \"self-host\""'
assert "JSON output lists self_host_markers" 'echo "$JSON_DEPLOY" | python3 -c "import json,sys; assert \"Dockerfile\" in json.load(sys.stdin)[\"deploy\"][\"self_host_markers\"]"'
rm -rf "$TMP_DEPLOY_JSON"


print_summary_and_exit
