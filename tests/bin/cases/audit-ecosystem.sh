#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

AUDIT="$AIKIT/bin/ai-kit-audit-ecosystem.sh"
FIX_ROOT="$AIKIT/tests/bin/fixtures/audit-ecosystem"

# Materialise the fixture into a temp dir so __ALIVE_PATH__ resolves to an
# existing directory unique to this run. installed_plugins.json templates the
# placeholder.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -R "$FIX_ROOT/home" "$WORK/home"
cp -R "$FIX_ROOT/catalog" "$WORK/catalog"
mkdir -p "$WORK/projects/alive"
ALIVE="$WORK/projects/alive"

# Replace placeholder with the real alive path. macOS sed needs -i ''.
sed -i.bak "s|__ALIVE_PATH__|$ALIVE|g" \
  "$WORK/home/.claude/plugins/installed_plugins.json"
rm "$WORK/home/.claude/plugins/installed_plugins.json.bak"

HOME_FIX="$WORK/home"
CATALOG_FIX="$WORK/catalog"
COMMON="--home $HOME_FIX --catalog-root $CATALOG_FIX"

echo "=== ai-kit-audit-ecosystem: smoke ==="
# section: audit-ecosystem-smoke
assert "audit --help exits 0" '"$AUDIT" --help >/dev/null 2>&1'
assert "audit unknown flag rejected" '! "$AUDIT" --bogus 2>/dev/null'
assert "audit invalid --scope rejected" '! "$AUDIT" --scope nonsense 2>/dev/null'

echo "=== ai-kit-audit-ecosystem: JSON shape ==="
# section: audit-ecosystem-json
set +e
JSON="$("$AUDIT" $COMMON --json 2>&1)"
JSON_EXIT=$?
set -e
assert "audit --json parses" 'echo "$JSON" | python3 -c "import json,sys; json.load(sys.stdin)"'
assert "audit --json carries findings array" 'echo "$JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"findings\"], list)"'
assert "audit --json carries total + divergent ints" 'echo "$JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"total\"], int) and isinstance(d[\"divergent\"], int)"'
assert "audit --json carries home + catalog_root + scope keys" 'echo "$JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(k in d for k in (\"home\",\"catalog_root\",\"scope\"))"'
assert "audit exit 1 when divergent findings present" '[ "$JSON_EXIT" -eq 1 ]'

echo "=== ai-kit-audit-ecosystem: verdict classification ==="
# section: audit-ecosystem-verdicts
find_verdict() {
  # find_verdict <name-substr> <expected-verdict>
  echo "$JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
needle = sys.argv[1]
expected = sys.argv[2]
for f in d['findings']:
    if needle in f['name'] and f['verdict'] == expected:
        sys.exit(0)
sys.stderr.write('no finding with name~' + needle + ' verdict=' + expected + '\n')
sys.exit(1)
" "$1" "$2"
}

assert "in-catalog plugin → OWNED" 'find_verdict "in-catalog@example" "OWNED"'
assert "stale projectPath → DROP-STALE" 'find_verdict "stale-path@example" "DROP-STALE"'
assert "dup-name across marketplaces → REBIND (first install)" 'find_verdict "dup-name@market-a" "REBIND"'
assert "dup-name across marketplaces → REBIND (second install)" 'find_verdict "dup-name@market-b" "REBIND"'
assert "ai@yusufkaracaburun project-scoped → REBIND" 'find_verdict "ai@yusufkaracaburun" "REBIND"'
assert "uncatalogued plugin → ADOPT" 'find_verdict "uncatalogued@example" "ADOPT"'
assert "user-skill shadowing plugin → REPLACE" 'find_verdict "dedupe" "REPLACE"'
assert "user-agent shadowing plugin → REPLACE" 'find_verdict "reviewer" "REPLACE"'
assert "user-rule matching catalog → OWNED" 'find_verdict "context7-fixture" "OWNED"'
assert "user-rule not in catalog → KEEP-EXTERNAL" 'find_verdict "personal-rule" "KEEP-EXTERNAL"'
assert "MCP server in catalog → OWNED" 'find_verdict "context7-fixture" "OWNED"'
assert "MCP server not in catalog → ADOPT" 'find_verdict "uncatalogued-mcp" "ADOPT"'
assert "marketplace with no installs → DROP" 'find_verdict "unused-marketplace" "DROP"'
assert "marketplace with installs → KEEP-EXTERNAL" 'find_verdict "example" "KEEP-EXTERNAL"'

echo "=== ai-kit-audit-ecosystem: --scope filter ==="
# section: audit-ecosystem-scope
set +e
PLUGINS_ONLY="$("$AUDIT" $COMMON --json --scope plugins 2>&1)"
set -e
assert "scope plugins yields only plugin findings" 'echo "$PLUGINS_ONLY" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(f[\"surface\"]==\"plugins\" for f in d[\"findings\"])"'

echo "=== ai-kit-audit-ecosystem: --converge prints, does not execute ==="
# section: audit-ecosystem-converge
# Ensure no side effects on host paths. Capture before/after of fixture skills dir.
BEFORE=$(ls -la "$WORK/home/.claude/skills" | wc -l)
set +e
CONV="$("$AUDIT" $COMMON --converge 2>&1)"
set -e
AFTER=$(ls -la "$WORK/home/.claude/skills" | wc -l)
assert "converge mentions /plugin uninstall for stale" 'echo "$CONV" | grep -q "/plugin uninstall stale-path@example"'
assert "converge mentions rebind for ai@yusufkaracaburun" 'echo "$CONV" | grep -q "/plugin uninstall ai@yusufkaracaburun"'
assert "converge mentions ADOPT candidate for uncatalogued" 'echo "$CONV" | grep -q "ADOPT candidate: plugins/uncatalogued@example"'
assert "converge proposes rm for REPLACE user-skill" 'echo "$CONV" | grep -q "rm -rf .*\\.claude/skills/dedupe"'
assert "converge did NOT execute (fixture skills dir unchanged)" '[ "$BEFORE" -eq "$AFTER" ] && [ -d "$WORK/home/.claude/skills/dedupe" ]'

echo "=== ai-kit-audit-ecosystem: clean fixture → exit 0 ==="
# section: audit-ecosystem-clean
CLEAN_HOME=$(mktemp -d)
mkdir -p "$CLEAN_HOME/.claude"
set +e
CLEAN_OUT="$("$AUDIT" --home "$CLEAN_HOME" --catalog-root "$CATALOG_FIX" --json 2>&1)"
CLEAN_EXIT=$?
set -e
assert "clean fixture → exit 0" '[ "$CLEAN_EXIT" -eq 0 ]'
assert "clean fixture → findings empty" 'echo "$CLEAN_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"total\"]==0 and d[\"divergent\"]==0"'
rm -rf "$CLEAN_HOME"

print_summary_and_exit
