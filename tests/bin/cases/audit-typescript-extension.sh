#!/usr/bin/env bash
# Integration test for the audit-architecture-typescript extension.
# Covers: artifact existence (SKILL + rule + helper), loader-match on a
# TS-shaped target (tsconfig.json), helper run_tools tool-gate, fixture shape
# (all 8 T-rule markers in tests/fixtures/audit-typescript-pure/), and the
# shared overlap fixture from #79 (TS-side: T-markers present).
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

SKILL="$AIKIT/workflow/skills/audit-architecture-typescript/SKILL.md"
RULE="$AIKIT/standards/rules/code-audit-typescript.mini.md"
HELPER="$AIKIT/bin/audit-typescript-helpers.sh"
LOADER="$AIKIT/bin/audit-extension-loader.sh"
PARSER="$AIKIT/bin/lib/parse-audit-extension-frontmatter.py"
FIXTURE="$AIKIT/tests/fixtures/audit-typescript-pure"
OVERLAP="$AIKIT/tests/fixtures/audit-react-ts-overlap"

echo "=== artifacts-exist ==="
assert "SKILL.md exists" '[ -f "$SKILL" ]'
assert "rule file exists" '[ -f "$RULE" ]'
assert "helper-script exists + executable" '[ -x "$HELPER" ]'
assert "typescript-pure fixture dir exists" '[ -d "$FIXTURE" ]'

echo "=== frontmatter ==="
PARSED="$(python3 "$PARSER" "$SKILL" 2>/dev/null || true)"
assert "frontmatter parses" '[ -n "$PARSED" ]'
assert "extends: audit-architecture" 'echo "$PARSED" | grep -q "^EXTENDS=audit-architecture$"'
assert "applies_to.languages contains typescript" 'echo "$PARSED" | grep -q "^LANGUAGES=.*typescript"'
assert "rule frontmatter has applies_to.languages: typescript" \
  'grep -A3 "applies_to:" "$RULE" | grep -q "typescript"'

echo "=== loader-match ==="
# Framework-agnostic — match via languages on tsconfig.json shape.
TARGET_TS=$(mktemp -d)
trap 'rm -rf "$TARGET_TS"' EXIT
cat > "$TARGET_TS/tsconfig.json" <<'JSON'
{ "compilerOptions": { "strict": true, "target": "ES2022" } }
JSON
OUTPUT=$("$LOADER" "$TARGET_TS" 2>/dev/null || true)
assert "loader matches audit-architecture-typescript on tsconfig.json target" \
  'echo "$OUTPUT" | grep -q "audit-architecture-typescript/SKILL.md$"'

echo "=== helper-tool-gate ==="
STATUS=$(PATH=/usr/bin:/bin "$HELPER" run_tools "$TARGET_TS" 2>/dev/null || true)
assert "run_tools emits header line" 'echo "$STATUS" | grep -qE "Tools ingested:"'
assert "run_tools gates tsc absence as ✗" 'echo "$STATUS" | grep -qE "tsc ✗"'
assert "run_tools gates ts-prune absence as ✗" 'echo "$STATUS" | grep -qE "ts-prune ✗"'
# force-strict notice in header.
assert "run_tools surfaces force-strict notice" 'echo "$STATUS" | grep -qE "force-strict"'

echo "=== fixture-shape ==="
for n in 1 2 3 4 5 6 7 8; do
  assert "typescript-pure fixture has T$n trigger" \
    'grep -rqE "T'"$n"':" "$FIXTURE" 2>/dev/null'
done

echo "=== overlap-fixture-ts-side ==="
# Shared #79 overlap fixture: must contain T* markers (TS-language smells).
assert "overlap fixture has at least one T* marker" \
  'grep -rqE "T[1-8]:" "$OVERLAP" 2>/dev/null'

print_summary_and_exit
