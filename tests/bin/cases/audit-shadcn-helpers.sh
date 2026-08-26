#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# audit-shadcn-helpers.sh's own subcommands (run_tools, read_aliases) — the
# one helper whose components.json parsing (valid / malformed / partial
# aliases) had zero coverage. Shared extension plumbing (SKILL.md, loader
# match) is covered by the react/typescript/laravel siblings already.

HELPER="$AIKIT/bin/audit-shadcn-helpers.sh"

echo "=== run_tools ==="
T=$(mktemp -d)
OUT=$("$HELPER" run_tools "$T")
assert "no components.json -> ✗" 'grep -qE "components.json ✗" <<<"$OUT"'

echo '{"aliases": {"ui": "@/components/ui"}}' > "$T/components.json"
OUT=$("$HELPER" run_tools "$T")
assert "valid components.json -> ✓" 'grep -qE "components.json ✓" <<<"$OUT"'

echo 'not json at all' > "$T/components.json"
OUT=$("$HELPER" run_tools "$T")
assert "malformed components.json -> ✗ (JSON validated, not just present)" \
  'grep -qE "components.json ✗" <<<"$OUT"'
rm -rf "$T"

echo "=== read_aliases ==="
T=$(mktemp -d)
OUT=$("$HELPER" read_aliases "$T")
assert "no components.json -> empty output" '[ -z "$OUT" ]'

python3 -c "
import json
json.dump({'aliases': {'ui': '@/components/ui', 'utils': '@/lib/utils'}}, open('$T/components.json', 'w'))
"
OUT=$("$HELPER" read_aliases "$T")
assert "known aliases printed as key=value" \
  'grep -qx "ui=@/components/ui" <<<"$OUT" && grep -qx "utils=@/lib/utils" <<<"$OUT"'
assert "aliases absent from the file are omitted" '! grep -q "^components=" <<<"$OUT"'

echo 'not json at all' > "$T/components.json"
OUT=$("$HELPER" read_aliases "$T")
assert "malformed components.json -> silently empty, no crash" '[ -z "$OUT" ]'
rm -rf "$T"

echo "=== usage / arg handling ==="
RC=0; "$HELPER" 2>/dev/null || RC=$?
assert "no args -> usage, exit 2" '[ "$RC" -eq 2 ]'

print_summary_and_exit
