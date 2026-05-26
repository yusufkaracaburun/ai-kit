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

echo "=== integration-xfail ==="
# These assertions describe what the contract-test will check once the
# React + TypeScript extensions land (#81, #82). Until then they XFAIL —
# we record the future-shape inline so reviewers see what's wired up.
EXT_REACT="$AIKIT/workflow/skills/audit-architecture-react/SKILL.md"
EXT_TS="$AIKIT/workflow/skills/audit-architecture-typescript/SKILL.md"

if [ -f "$EXT_REACT" ] && [ -f "$EXT_TS" ]; then
  # Once both extensions exist, the integration assertions must be real —
  # fail loud if this test case still ships the XFAIL stub, so the green
  # bar cannot lie about coverage.
  assert "integration assertions implemented (extensions #81/#82 present)" \
    'false  # implement the de-dup + per-prefix assertions here'
else
  echo "  XFAIL: integration assertions skipped (extensions #81/#82 not yet bundled)"
fi

print_summary_and_exit
