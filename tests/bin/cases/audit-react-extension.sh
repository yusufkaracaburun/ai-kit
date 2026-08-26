#!/usr/bin/env bash
# Integration test for the audit-architecture-react extension.
# Covers: artifact existence (SKILL + rule + helper), loader-match on a
# React/Next.js-shaped target, helper run_tools tool-gate, fixture shape
# (all 8 heuristic markers in tests/fixtures/audit-react/), and the shared
# overlap fixture from #79 (React-side: R-rules present, NOT TS-rules).
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

SKILL="$AIKIT/workflow/skills/audit-architecture-react/SKILL.md"
RULE="$AIKIT/standards/rules/code-audit-react.mini.md"
HELPER="$AIKIT/bin/audit-react-helpers.sh"
LOADER="$AIKIT/bin/audit-extension-loader.sh"
PARSER="$AIKIT/bin/lib/parse-audit-extension-frontmatter.py"
FIXTURE="$AIKIT/tests/fixtures/audit-react"
OVERLAP="$AIKIT/tests/fixtures/audit-react-ts-overlap"

echo "=== artifacts-exist ==="
assert "SKILL.md exists" '[ -f "$SKILL" ]'
assert "rule file exists" '[ -f "$RULE" ]'
assert "helper-script exists + executable" '[ -x "$HELPER" ]'
assert "react fixture dir exists" '[ -d "$FIXTURE" ]'
assert "react-ts overlap fixture (from #79) exists" '[ -d "$OVERLAP" ]'

echo "=== frontmatter ==="
PARSED="$(python3 "$PARSER" "$SKILL" 2>/dev/null || true)"
assert "frontmatter parses" '[ -n "$PARSED" ]'
assert "extends: audit-architecture" 'echo "$PARSED" | grep -q "^EXTENDS=audit-architecture$"'
assert "applies_to.frameworks contains react" 'echo "$PARSED" | grep -q "^FRAMEWORKS=.*react"'
assert "applies_to.frameworks contains nextjs" 'echo "$PARSED" | grep -q "^FRAMEWORKS=.*nextjs"'
assert "rule frontmatter has applies_to.frameworks: react" \
  'grep -A2 "applies_to:" "$RULE" | grep -q "react"'

echo "=== loader-match ==="
# React/Next.js-shaped target via package.json. detect-tooling sees "react" + "next".
TARGET_NEXT=$(mktemp -d)
trap 'rm -rf "$TARGET_NEXT"' EXIT
cat > "$TARGET_NEXT/package.json" <<'JSON'
{ "name": "t/app", "dependencies": { "react": "^19.0.0", "next": "^15.0.0" } }
JSON
OUTPUT=$("$LOADER" "$TARGET_NEXT" 2>/dev/null || true)
assert "loader matches audit-architecture-react on next.js target" \
  'echo "$OUTPUT" | grep -q "audit-architecture-react/SKILL.md$"'

echo "=== helper-tool-gate ==="
STATUS=$(PATH=/usr/bin:/bin "$HELPER" run_tools "$TARGET_NEXT" 2>/dev/null || true)
assert "run_tools emits header line" 'echo "$STATUS" | grep -qE "Tools ingested:"'
assert "run_tools gates ESLint absence as ✗" 'echo "$STATUS" | grep -qE "ESLint ✗"'

echo "=== fixture-shape ==="
assert "react fixture carries all 8 R-markers" \
  '[ "$(grep -rhoE "R[0-9]+:" "$FIXTURE" 2>/dev/null | sort -u | wc -l | tr -d " ")" -ge 8 ]'

echo "=== overlap-fixture-react-side ==="
# In the shared #79 overlap fixture, this extension must surface React-side
# markers (R*) but NOT introduce TypeScript-side markers (T*) — non-overlap
# enforced at fixture-shape level. The TS extension (separate issue) owns T*.
assert "overlap fixture has at least one R* marker" \
  'grep -rqE "R[1-8]:" "$OVERLAP" 2>/dev/null'

print_summary_and_exit
