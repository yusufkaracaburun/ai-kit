#!/usr/bin/env bash
# Table-driven integration test for the three audit-architecture-* extensions
# (react, typescript, laravel). Replaces audit-react-extension.sh,
# audit-typescript-extension.sh and audit-laravel-extension.sh, which were
# the same ~65-line file three times over with a marker letter and a handful
# of names substituted.
#
# Common per-row sections: artifacts-exist, frontmatter, loader-match,
# helper-tool-gate, fixture-shape. Stack-specific quirks are kept as explicit
# escape hatches rather than flattened away:
#   - typescript: extra force-strict notice in run_tools output, and its rule
#     frontmatter needs -A3 (not -A2) to reach the "languages:" line.
#   - laravel: dual fixtures (api-only / full-stack) instead of one, and an
#     extra helper-mode-detect section with no react/typescript equivalent.
#   - react + typescript (not laravel): the shared #79 overlap fixture, each
#     asserting its own marker family is present.
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

LOADER="$AIKIT/bin/audit-extension-loader.sh"
PARSER="$AIKIT/bin/lib/parse-audit-extension-frontmatter.py"
OVERLAP="$AIKIT/tests/fixtures/audit-react-ts-overlap"

CLEANUP_DIRS=()
trap 'rm -rf "${CLEANUP_DIRS[@]}"' EXIT

echo "=== overlap-fixture-exists (shared by react + typescript, #79) ==="
assert "react-ts overlap fixture (from #79) exists" '[ -d "$OVERLAP" ]'

for KEY in react typescript laravel vue; do
  echo "=== audit-extensions: $KEY ==="

  case "$KEY" in
    react)
      SKILL="$AIKIT/workflow/skills/audit-architecture-react/SKILL.md"
      RULE="$AIKIT/standards/rules/code-audit-react.mini.md"
      HELPER="$AIKIT/bin/audit-react-helpers.sh"
      MARKER=R
      APPLIES_KEY=FRAMEWORKS
      APPLIES_VALUES=(react nextjs)
      RULE_CONTEXT=-A2
      RULE_VALUE=react
      TARGET_FILE=package.json
      TARGET_CONTENT='{ "name": "t/app", "dependencies": { "react": "^19.0.0", "next": "^15.0.0" } }'
      TOOL_GATE_CHECKS=("ESLint ✗")
      ;;
    typescript)
      SKILL="$AIKIT/workflow/skills/audit-architecture-typescript/SKILL.md"
      RULE="$AIKIT/standards/rules/code-audit-typescript.mini.md"
      HELPER="$AIKIT/bin/audit-typescript-helpers.sh"
      MARKER=T
      APPLIES_KEY=LANGUAGES
      APPLIES_VALUES=(typescript)
      RULE_CONTEXT=-A3
      RULE_VALUE=typescript
      TARGET_FILE=tsconfig.json
      TARGET_CONTENT='{ "compilerOptions": { "strict": true, "target": "ES2022" } }'
      TOOL_GATE_CHECKS=("tsc ✗" "ts-prune ✗")
      ;;
    laravel)
      SKILL="$AIKIT/workflow/skills/audit-architecture-laravel/SKILL.md"
      RULE="$AIKIT/standards/rules/code-audit-laravel.mini.md"
      HELPER="$AIKIT/bin/audit-laravel-helpers.sh"
      MARKER=L
      APPLIES_KEY=FRAMEWORKS
      APPLIES_VALUES=(laravel)
      RULE_CONTEXT=-A2
      RULE_VALUE=laravel
      TARGET_FILE=composer.json
      TARGET_CONTENT='{ "name": "t/api", "require": { "laravel/framework": "^13.0" } }'
      TOOL_GATE_CHECKS=("Larastan ✗")
      ;;
    vue)
      SKILL="$AIKIT/workflow/skills/audit-architecture-vue/SKILL.md"
      RULE="$AIKIT/standards/rules/code-audit-vue.mini.md"
      HELPER="$AIKIT/bin/audit-vue-helpers.sh"
      MARKER=V
      APPLIES_KEY=FRAMEWORKS
      APPLIES_VALUES=(vue)
      RULE_CONTEXT=-A2
      RULE_VALUE=vue
      TARGET_FILE=package.json
      TARGET_CONTENT='{ "name": "t/app", "dependencies": { "vue": "^3.5.0" } }'
      TOOL_GATE_CHECKS=("ESLint ✗" "vue-tsc ✗")
      ;;
  esac
  EXT_NAME="$(basename "$(dirname "$SKILL")")"

  echo "--- artifacts-exist ---"
  assert "$KEY: SKILL.md exists" '[ -f "$SKILL" ]'
  assert "$KEY: rule file exists" '[ -f "$RULE" ]'
  assert "$KEY: helper-script exists + executable" '[ -x "$HELPER" ]'

  echo "--- frontmatter ---"
  PARSED="$(python3 "$PARSER" "$SKILL" 2>/dev/null || true)"
  assert "$KEY: frontmatter parses" '[ -n "$PARSED" ]'
  assert "$KEY: extends: audit-architecture" 'echo "$PARSED" | grep -q "^EXTENDS=audit-architecture$"'
  for v in "${APPLIES_VALUES[@]}"; do
    assert "$KEY: applies_to.$APPLIES_KEY contains $v" \
      'echo "$PARSED" | grep -q "^$APPLIES_KEY=.*$v"'
  done
  assert "$KEY: rule frontmatter has applies_to.$APPLIES_KEY: $RULE_VALUE" \
    'grep $RULE_CONTEXT "applies_to:" "$RULE" | grep -q "$RULE_VALUE"'

  echo "--- loader-match ---"
  TARGET=$(mktemp -d)
  CLEANUP_DIRS+=("$TARGET")
  printf '%s\n' "$TARGET_CONTENT" > "$TARGET/$TARGET_FILE"
  OUTPUT=$("$LOADER" "$TARGET" 2>/dev/null || true)
  assert "$KEY: loader matches $EXT_NAME on $TARGET_FILE target" \
    'echo "$OUTPUT" | grep -q "$EXT_NAME/SKILL.md$"'

  echo "--- helper-tool-gate ---"
  STATUS=$(PATH=/usr/bin:/bin "$HELPER" run_tools "$TARGET" 2>/dev/null || true)
  assert "$KEY: run_tools emits header line" 'echo "$STATUS" | grep -qE "Tools ingested:"'
  for chk in "${TOOL_GATE_CHECKS[@]}"; do
    assert "$KEY: run_tools gates ${chk% ✗} absence as ✗" 'echo "$STATUS" | grep -qE "$chk"'
  done
  if [ "$KEY" = typescript ]; then
    assert "$KEY: run_tools surfaces force-strict notice" 'echo "$STATUS" | grep -qE "force-strict"'
  fi

  echo "--- fixture-shape ---"
  case "$KEY" in
    react)
      FIXTURE="$AIKIT/tests/fixtures/audit-react"
      assert "$KEY: fixture dir exists" '[ -d "$FIXTURE" ]'
      assert "$KEY: fixture carries all 9 R-markers" \
        '[ "$(grep -rhoE "R[0-9]+:" "$FIXTURE" 2>/dev/null | sort -u | wc -l | tr -d " ")" -ge 9 ]'
      ;;
    typescript)
      FIXTURE="$AIKIT/tests/fixtures/audit-typescript-pure"
      assert "$KEY: fixture dir exists" '[ -d "$FIXTURE" ]'
      for n in 1 2 3 4 5 6 7 8; do
        assert "$KEY: fixture has T$n trigger" \
          'grep -rqE "T'"$n"':" "$FIXTURE" 2>/dev/null'
      done
      ;;
    laravel)
      # Laravel gets dual fixtures instead of one: api-only must carry every
      # heuristic, full-stack must omit the three api-only-specific ones.
      FIXTURE_API="$AIKIT/tests/fixtures/audit-laravel-api-only"
      FIXTURE_FULL="$AIKIT/tests/fixtures/audit-laravel-full-stack"
      assert "$KEY: api-only fixture dir exists" '[ -d "$FIXTURE_API" ]'
      assert "$KEY: full-stack fixture dir exists" '[ -d "$FIXTURE_FULL" ]'
      assert "$KEY: api-only fixture carries all 22 L-markers" \
        '[ "$(grep -rhoE "L[0-9]+:" "$FIXTURE_API" 2>/dev/null | sort -u | wc -l | tr -d " ")" -ge 22 ]'
      for n in 14 16 18; do
        assert "$KEY: full-stack fixture omits L$n (api-only)" \
          '! grep -rqE "L'"$n"':" "$FIXTURE_FULL" 2>/dev/null'
      done
      assert "$KEY: full-stack fixture carries the 19 both-mode L-markers" \
        '[ "$(grep -rhoE "L[0-9]+:" "$FIXTURE_FULL" 2>/dev/null | sort -u | wc -l | tr -d " ")" -ge 19 ]'
      ;;
    vue)
      FIXTURE="$AIKIT/tests/fixtures/audit-vue"
      assert "$KEY: fixture dir exists" '[ -d "$FIXTURE" ]'
      assert "$KEY: fixture carries all 8 V-markers" \
        '[ "$(grep -rhoE "V[0-9]+:" "$FIXTURE" 2>/dev/null | sort -u | wc -l | tr -d " ")" -ge 8 ]'
      # V6 needs two sibling feature roots to have a boundary to cross.
      assert "$KEY: fixture has >=2 feature roots (V6 precondition)" \
        '[ "$(find "$FIXTURE/src/features" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d " ")" -ge 2 ]'
      # V2 fires only on a mixed codebase — the fixture must actually be mixed.
      assert "$KEY: detect_api reports mixed (V2 precondition)" \
        '[ "$("$HELPER" detect_api "$FIXTURE" 2>/dev/null)" = "mixed" ]'
      # Regression: `defineComponent({…})` is the dominant Options form in TS
      # codebases. Counting only `export default {` reported `none` for a repo
      # of 684 such SFCs, which inverted V2 onto the <script setup> minority.
      DC_TARGET=$(mktemp -d)
      CLEANUP_DIRS+=("$DC_TARGET")
      printf '<script lang="ts">\nexport default defineComponent({\n  data() { return {}; },\n});\n</script>\n' \
        > "$DC_TARGET/Legacy.vue"
      assert "$KEY: detect_api counts defineComponent() as options" \
        '[ "$("$HELPER" detect_api "$DC_TARGET" 2>/dev/null)" = "options" ]'
      printf '<script lang="ts">\nexport default defineComponent({\n  setup() { return {}; },\n});\n</script>\n' \
        > "$DC_TARGET/Modern.vue"
      assert "$KEY: detect_api counts defineComponent with setup() as mixed" \
        '[ "$("$HELPER" detect_api "$DC_TARGET" 2>/dev/null)" = "mixed" ]'
      ;;
  esac

  if [ "$KEY" = react ] || [ "$KEY" = typescript ]; then
    echo "--- overlap-fixture ($KEY-side) ---"
    # Non-overlap enforced here: this extension's marker family must appear
    # in the shared fixture without asserting the other family's absence —
    # that's the sibling row's job, not this one's.
    assert "$KEY: overlap fixture has at least one $MARKER* marker" \
      'grep -rqE "$MARKER[1-8]:" "$OVERLAP" 2>/dev/null'
  fi

  if [ "$KEY" = laravel ]; then
    echo "--- helper-mode-detect ---"
    mkdir -p "$TARGET/routes" "$TARGET/resources/views"
    echo "<?php // api routes" > "$TARGET/routes/api.php"
    echo "Route::get('/foo', fn() => 'bar');" >> "$TARGET/routes/api.php"
    MODE=$("$HELPER" detect_mode "$TARGET" 2>/dev/null || true)
    assert "$KEY: detect_mode api-only" '[ "$MODE" = "api-only" ]'

    TARGET_INERTIA=$(mktemp -d)
    CLEANUP_DIRS+=("$TARGET_INERTIA")
    mkdir -p "$TARGET_INERTIA/routes"
    cat > "$TARGET_INERTIA/composer.json" <<'JSON'
{ "require": { "laravel/framework": "^13.0", "inertiajs/inertia-laravel": "^1.0" } }
JSON
    echo "<?php" > "$TARGET_INERTIA/routes/api.php"
    MODE_INERTIA=$("$HELPER" detect_mode "$TARGET_INERTIA" 2>/dev/null || true)
    assert "$KEY: detect_mode full-stack on inertia" '[ "$MODE_INERTIA" = "full-stack" ]'

    TARGET_FULL=$(mktemp -d)
    CLEANUP_DIRS+=("$TARGET_FULL")
    mkdir -p "$TARGET_FULL/routes" "$TARGET_FULL/resources/views"
    cat > "$TARGET_FULL/composer.json" <<'JSON'
{ "require": { "laravel/framework": "^13.0" } }
JSON
    echo "<?php" > "$TARGET_FULL/routes/api.php"
    echo "<h1>hi</h1>" > "$TARGET_FULL/resources/views/welcome.blade.php"
    MODE_FULL=$("$HELPER" detect_mode "$TARGET_FULL" 2>/dev/null || true)
    assert "$KEY: detect_mode full-stack on blade views" '[ "$MODE_FULL" = "full-stack" ]'

    MODE_OVERRIDE=$(AI_KIT_AUDIT_LARAVEL_MODE=api-only "$HELPER" detect_mode "$TARGET_FULL" 2>/dev/null || true)
    assert "$KEY: AI_KIT_AUDIT_LARAVEL_MODE overrides detection" '[ "$MODE_OVERRIDE" = "api-only" ]'
  fi
done

print_summary_and_exit
