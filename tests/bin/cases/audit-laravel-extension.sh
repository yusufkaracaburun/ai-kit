#!/usr/bin/env bash
# Integration test for the audit-architecture-laravel extension.
# Covers: artifact existence (SKILL + rule + helper), loader-match on a
# Laravel-shaped target, helper mode-detect (api-only / full-stack / env
# override), tool-gate graceful-degrade, fixture shape (all 22 heuristic
# triggers present in api-only fixture; L14/L16/L18 absent from full-stack).
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

SKILL="$AIKIT/workflow/skills/audit-architecture-laravel/SKILL.md"
RULE="$AIKIT/standards/rules/code-audit-laravel.mini.md"
HELPER="$AIKIT/bin/audit-laravel-helpers.sh"
LOADER="$AIKIT/bin/audit-extension-loader.sh"
PARSER="$AIKIT/bin/lib/parse-audit-extension-frontmatter.py"
FIXTURE_API="$AIKIT/tests/fixtures/audit-laravel-api-only"
FIXTURE_FULL="$AIKIT/tests/fixtures/audit-laravel-full-stack"

echo "=== artifacts-exist ==="
assert "SKILL.md exists" '[ -f "$SKILL" ]'
assert "rule file exists" '[ -f "$RULE" ]'
assert "helper-script exists + executable" '[ -x "$HELPER" ]'
assert "api-only fixture dir exists" '[ -d "$FIXTURE_API" ]'
assert "full-stack fixture dir exists" '[ -d "$FIXTURE_FULL" ]'

echo "=== frontmatter ==="
PARSED="$(python3 "$PARSER" "$SKILL" 2>/dev/null || true)"
assert "frontmatter parses" '[ -n "$PARSED" ]'
assert "extends: audit-architecture" 'echo "$PARSED" | grep -q "^EXTENDS=audit-architecture$"'
assert "applies_to.frameworks contains laravel" 'echo "$PARSED" | grep -q "^FRAMEWORKS=.*laravel"'

assert "rule frontmatter has applies_to.frameworks: laravel" \
  'grep -A2 "applies_to:" "$RULE" | grep -q "laravel"'

echo "=== loader-match-default ==="
# With default skills-dir, loader returns the bundled laravel extension on a
# laravel-shaped target.
TARGET_LARAVEL=$(mktemp -d)
trap 'rm -rf "$TARGET_LARAVEL" "$TARGET_FULL" "$TARGET_INERTIA"' EXIT
cat > "$TARGET_LARAVEL/composer.json" <<'JSON'
{ "name": "t/api", "require": { "laravel/framework": "^13.0" } }
JSON
OUTPUT=$("$LOADER" "$TARGET_LARAVEL" 2>/dev/null || true)
assert "default loader picks up audit-architecture-laravel" \
  'echo "$OUTPUT" | grep -q "audit-architecture-laravel/SKILL.md$"'

echo "=== helper-mode-detect ==="
# api-only: routes/api.php non-empty, no Inertia/Blade.
mkdir -p "$TARGET_LARAVEL/routes" "$TARGET_LARAVEL/resources/views"
echo "<?php // api routes" > "$TARGET_LARAVEL/routes/api.php"
echo "Route::get('/foo', fn() => 'bar');" >> "$TARGET_LARAVEL/routes/api.php"
MODE=$("$HELPER" detect_mode "$TARGET_LARAVEL" 2>/dev/null || true)
assert "detect_mode api-only" '[ "$MODE" = "api-only" ]'

# full-stack: Inertia marker in composer.
TARGET_INERTIA=$(mktemp -d)
mkdir -p "$TARGET_INERTIA/routes"
cat > "$TARGET_INERTIA/composer.json" <<'JSON'
{ "require": { "laravel/framework": "^13.0", "inertiajs/inertia-laravel": "^1.0" } }
JSON
echo "<?php" > "$TARGET_INERTIA/routes/api.php"
MODE_INERTIA=$("$HELPER" detect_mode "$TARGET_INERTIA" 2>/dev/null || true)
assert "detect_mode full-stack on inertia" '[ "$MODE_INERTIA" = "full-stack" ]'

# full-stack: Blade views non-empty.
TARGET_FULL=$(mktemp -d)
mkdir -p "$TARGET_FULL/routes" "$TARGET_FULL/resources/views"
cat > "$TARGET_FULL/composer.json" <<'JSON'
{ "require": { "laravel/framework": "^13.0" } }
JSON
echo "<?php" > "$TARGET_FULL/routes/api.php"
echo "<h1>hi</h1>" > "$TARGET_FULL/resources/views/welcome.blade.php"
MODE_FULL=$("$HELPER" detect_mode "$TARGET_FULL" 2>/dev/null || true)
assert "detect_mode full-stack on blade views" '[ "$MODE_FULL" = "full-stack" ]'

# env-var override.
MODE_OVERRIDE=$(AI_KIT_AUDIT_LARAVEL_MODE=api-only "$HELPER" detect_mode "$TARGET_FULL" 2>/dev/null || true)
assert "AI_KIT_AUDIT_LARAVEL_MODE overrides detection" '[ "$MODE_OVERRIDE" = "api-only" ]'

echo "=== helper-tool-gate ==="
# Without phpstan/composer on PATH (we don't ship those in CI), run_tools must
# complete and print tool-status with ✗ markers.
STATUS=$(PATH=/usr/bin:/bin "$HELPER" run_tools "$TARGET_LARAVEL" 2>/dev/null || true)
assert "run_tools emits header line" 'echo "$STATUS" | grep -qE "Tools ingested:"'
assert "run_tools gates Larastan absence as ✗" 'echo "$STATUS" | grep -qE "Larastan ✗"'

echo "=== fixture-shape-api-only ==="
# api-only fixture must contain a trigger marker for each heuristic L1..L22.
# Markers are simple grep-able tokens in fixture filenames or contents.
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22; do
  assert "api-only fixture has L$n trigger" \
    'grep -rqE "L'"$n"':" "$FIXTURE_API" 2>/dev/null'
done

echo "=== fixture-shape-full-stack ==="
# full-stack omits api-only-only heuristics (L14, L16, L18).
for n in 14 16 18; do
  assert "full-stack fixture omits L$n (api-only)" \
    '! grep -rqE "L'"$n"':" "$FIXTURE_FULL" 2>/dev/null'
done
# But still has the both-mode heuristics that apply to full-stack.
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 15 17 19 20 21 22; do
  assert "full-stack fixture has L$n trigger" \
    'grep -rqE "L'"$n"':" "$FIXTURE_FULL" 2>/dev/null'
done

print_summary_and_exit
