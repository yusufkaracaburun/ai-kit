#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

FIXTURE="$AIKIT/tests/fixtures/audit-react-ts-overlap"

echo "=== fixture-shape ==="
assert "fixture directory exists" '[ -d "$FIXTURE" ]'
assert "fixture has tsconfig.json" '[ -f "$FIXTURE/tsconfig.json" ]'
assert "fixture has package.json with react" 'grep -q "\"react\"" "$FIXTURE/package.json"'
assert "fixture has package.json with typescript" 'grep -q "\"typescript\"" "$FIXTURE/package.json"'
assert "fixture has at least one .tsx" 'find "$FIXTURE/src" -name "*.tsx" -print -quit | grep -q .'
assert "fixture has at least one .ts (non-tsx)" 'find "$FIXTURE/src" -name "*.ts" ! -name "*.tsx" -print -quit | grep -q .'
assert "fixture README documents ownership" \
  'grep -qE "audit-architecture-react|audit-architecture-typescript" "$FIXTURE/README.md"'

echo "=== react-shaped-smell-present ==="
# Dashboard.tsx must demonstrably contain a React-shaped smell (props-bloat)
# so that audit-architecture-react has something to flag when it lands.
assert "Dashboard component is exported" 'grep -q "export function Dashboard" "$FIXTURE/src/Dashboard.tsx"'
PROP_COUNT=$(awk '/^interface DashboardProps/,/^}/' "$FIXTURE/src/Dashboard.tsx" | grep -cE '^\s+\w+[?:]?:\s' || true)
assert "Dashboard has >8 props (R2 trigger)" '[ "$PROP_COUNT" -gt 8 ]'

echo "=== ts-shaped-smell-present ==="
# api.ts must demonstrably contain TS-only smells (any-past-boundary, as-cast)
# so that audit-architecture-typescript has something to flag when it lands.
assert "api.ts exports a function with any-past-boundary (T1 trigger)" \
  'grep -qE "export function.*: any" "$FIXTURE/src/api.ts"'
assert "api.ts has an as-cast past system edge (T2 trigger)" \
  'grep -q " as User" "$FIXTURE/src/api.ts"'

echo "=== ownership-non-overlap ==="
# Dashboard.tsx (React surface) must NOT also contain TS-only smells, and
# api.ts (TS surface) must NOT also contain React patterns — otherwise the
# de-dup assertion downstream becomes ambiguous.
assert "Dashboard.tsx contains no any-past-boundary" \
  '! grep -qE "export function.*: any" "$FIXTURE/src/Dashboard.tsx"'
assert "api.ts contains no JSX / Component patterns" \
  '! grep -qE "(<[A-Z]|export function [A-Z].*Props)" "$FIXTURE/src/api.ts"'

echo "=== integration ==="
# Once both extensions land (#81 react, #82 typescript), the contract-test
# verifies ownership-boundary discipline at the artifact level. The
# actual /ai:audit-architecture invocation is LLM-driven and not
# deterministically scriptable here, so we assert the contract surface:
#
#   (a) Both extensions exist and declare the boundary in their SKILL.md.
#   (b) The loader returns both extensions when run against the overlap
#       fixture (it's a tsconfig+react shape, so each extension applies).
#   (c) Fixture-level non-overlap: the React-side file holds R* markers
#       only, the TS-side file holds T* markers only. No file mixes.
EXT_REACT="$AIKIT/workflow/skills/audit-architecture-react/SKILL.md"
EXT_TS="$AIKIT/workflow/skills/audit-architecture-typescript/SKILL.md"
LOADER="$AIKIT/bin/audit-extension-loader.sh"

assert "audit-architecture-react SKILL.md exists" '[ -f "$EXT_REACT" ]'
assert "audit-architecture-typescript SKILL.md exists" '[ -f "$EXT_TS" ]'
assert "react SKILL.md declares boundary with typescript ext" \
  'grep -qE "audit-architecture-typescript|ownership boundary" "$EXT_REACT"'
assert "typescript SKILL.md declares boundary with react ext" \
  'grep -qE "audit-architecture-react|ownership rule" "$EXT_TS"'

# Loader returns both extensions when invoked against the overlap fixture.
LOADER_OUT=$("$LOADER" "$FIXTURE" 2>/dev/null || true)
assert "loader matches react extension on overlap fixture" \
  'echo "$LOADER_OUT" | grep -q "audit-architecture-react/SKILL.md$"'
assert "loader matches typescript extension on overlap fixture" \
  'echo "$LOADER_OUT" | grep -q "audit-architecture-typescript/SKILL.md$"'

# Fixture-level non-overlap: Dashboard.tsx has R* markers, NOT T* markers.
assert "Dashboard.tsx has at least one R* marker" \
  'grep -qE "R[1-8]:" "$FIXTURE/src/Dashboard.tsx"'
assert "Dashboard.tsx has no T* marker (would indicate overlap)" \
  '! grep -qE "T[1-8]:" "$FIXTURE/src/Dashboard.tsx"'

# api.ts has T* markers, NOT R* markers.
assert "api.ts has at least one T* marker" \
  'grep -qE "T[1-8]:" "$FIXTURE/src/api.ts"'
assert "api.ts has no R* marker (would indicate overlap)" \
  '! grep -qE "R[1-8]:" "$FIXTURE/src/api.ts"'

print_summary_and_exit
