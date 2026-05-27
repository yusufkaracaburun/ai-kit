#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

DEDUPE="$AIKIT/bin/ai-kit-dedupe.sh"

echo "=== ai-kit-dedupe: basic invocation ==="
# section: ai-kit-dedupe

# Smoke: --help exits 0 and prints usage.
assert "dedupe --help exits 0" '"$DEDUPE" --help >/dev/null 2>&1'
assert "dedupe --help prints usage" '"$DEDUPE" --help 2>&1 | grep -q "Scan for ai-kit duplication"'

# Smoke: empty target dir + report-only default = always exit 0.
EMPTY_TMP=$(mktemp -d)
set +e
"$DEDUPE" "$EMPTY_TMP" >/dev/null 2>&1
EMPTY_EXIT=$?
set -e
assert "dedupe empty target: exit 0 always (report-only default)" '[ "$EMPTY_EXIT" -eq 0 ]'

set +e
JSON_OUT="$("$DEDUPE" "$EMPTY_TMP" --json 2>&1)"
set -e
assert "dedupe --json emits parseable JSON" 'echo "$JSON_OUT" | python3 -c "import json,sys; json.load(sys.stdin)"'
assert "dedupe --json has dup_skills key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"dup_skills\" in d"'
assert "dedupe --json has dup_agents key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"dup_agents\" in d"'
assert "dedupe --json has orphan_rules key" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"orphan_rules\" in d"'
assert "dedupe --json has total field" 'echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"total\"], int)"'
rm -rf "$EMPTY_TMP"

echo "=== ai-kit-dedupe: orphan rule detection ==="
# section: ai-kit-dedupe-orphan

# Stage a project with one valid emitted rule + one orphan.
PROJ_TMP=$(mktemp -d)
mkdir -p "$PROJ_TMP/.cursor/rules"
# Pick a rule we know exists in the plugin.
touch "$PROJ_TMP/.cursor/rules/ai-kit-context-discipline.mdc"
# Stage an orphan — name that doesn't match any rule in standards/rules/.
touch "$PROJ_TMP/.cursor/rules/ai-kit-totally-fake-rule-xyz.mdc"

set +e
JSON_ORPHAN="$("$DEDUPE" "$PROJ_TMP" --json 2>&1)"
set -e
assert "dedupe orphan detected" 'echo "$JSON_ORPHAN" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(\"totally-fake-rule-xyz\" in r for r in d[\"orphan_rules\"])"'
assert "dedupe valid rule NOT flagged orphan" 'echo "$JSON_ORPHAN" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not any(\"context-discipline\" in r for r in d[\"orphan_rules\"])"'

# --fix prints rm command for the orphan, doesn't execute.
set +e
FIX_OUT="$("$DEDUPE" "$PROJ_TMP" --fix 2>&1)"
set -e
assert "dedupe --fix prints rm for orphan" 'echo "$FIX_OUT" | grep -q "rm \".*totally-fake-rule-xyz.mdc\""'
assert "dedupe --fix did NOT execute (orphan file still present)" '[ -f "$PROJ_TMP/.cursor/rules/ai-kit-totally-fake-rule-xyz.mdc" ]'

# Exit-code semantics: default report-only (exit 0), --strict exits 1 on findings.
set +e
"$DEDUPE" "$PROJ_TMP" >/dev/null 2>&1
DEFAULT_EXIT=$?
"$DEDUPE" "$PROJ_TMP" --strict >/dev/null 2>&1
STRICT_EXIT=$?
set -e
assert "dedupe default exit 0 even with orphan findings (report-only)" '[ "$DEFAULT_EXIT" -eq 0 ]'
assert "dedupe --strict exit 1 when orphan findings present" '[ "$STRICT_EXIT" -eq 1 ]'

rm -rf "$PROJ_TMP"

echo "=== ai-kit-dedupe: unknown flag rejected ==="
# section: ai-kit-dedupe-flags
assert "dedupe rejects unknown flag" '! "$DEDUPE" --bogus-flag >/dev/null 2>&1'

echo "=== ai-kit-dedupe: Surface 5 ecosystem integration ==="
# section: ai-kit-dedupe-ecosystem
EMPTY_TMP2=$(mktemp -d)
set +e
S5_JSON="$("$DEDUPE" "$EMPTY_TMP2" --json 2>&1)"
set -e
assert "dedupe --json carries ecosystem block by default" 'echo "$S5_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"ecosystem\" in d"'
assert "ecosystem block has findings array" 'echo "$S5_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"ecosystem\"][\"findings\"], list)"'

S5_HUMAN="$("$DEDUPE" "$EMPTY_TMP2" 2>&1 || true)"
assert "dedupe human output includes Surface 5 header" 'echo "$S5_HUMAN" | grep -q "Surface 5 — Ecosystem audit"'

S5_SKIP_JSON="$("$DEDUPE" "$EMPTY_TMP2" --no-ecosystem --json 2>&1 || true)"
assert "dedupe --no-ecosystem still carries ecosystem key (empty)" 'echo "$S5_SKIP_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"ecosystem\"][\"total\"]==0 and d[\"ecosystem\"][\"divergent\"]==0"'

S5_SKIP_HUMAN="$("$DEDUPE" "$EMPTY_TMP2" --no-ecosystem 2>&1 || true)"
assert "dedupe --no-ecosystem human output marks Surface 5 skipped" 'echo "$S5_SKIP_HUMAN" | grep -q "skip"'

rm -rf "$EMPTY_TMP2"

echo "=== ai-kit-dedupe: Surface 5 EXCLUDED count surfaces ==="
# section: ai-kit-dedupe-excluded
# Stage a minimal $HOME with one installed plugin that matches a real entry in
# ai-kit's standards/external/plugins-excluded.json. Pull the first excluded
# name dynamically so this test survives catalog changes.
EXCL_NAME="$(python3 -c "import json; print(json.load(open('$AIKIT/standards/external/plugins-excluded.json'))['excluded'][0]['name'])")"
EX_WORK=$(mktemp -d)
mkdir -p "$EX_WORK/home/.claude/plugins" "$EX_WORK/proj"
python3 - <<PY > "$EX_WORK/home/.claude/plugins/installed_plugins.json"
import json
print(json.dumps({
    "version": 2,
    "plugins": {
        "$EXCL_NAME@claude-plugins-official": [
            {"scope": "user", "installPath": "/tmp/fake/excl", "version": "0.0.1"}
        ]
    },
}))
PY

set +e
EX_HUMAN="$(HOME="$EX_WORK/home" "$DEDUPE" "$EX_WORK/proj" 2>&1)"
EX_JSON="$(HOME="$EX_WORK/home" "$DEDUPE" "$EX_WORK/proj" --json 2>&1)"
set -e
assert "dedupe ecosystem JSON contains EXCLUDED finding" 'echo "$EX_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(f[\"verdict\"]==\"EXCLUDED\" for f in d[\"ecosystem\"][\"findings\"])"'
assert "dedupe human Surface 5 mentions excluded count distinctly" 'echo "$EX_HUMAN" | grep -qi "excluded"'
# Issue #86: when divergent>0, Surface 5 inlines the per-item verdict table
# from ai-kit-audit-ecosystem.sh (so users don't have to copy an absolute
# path and re-run). Assertions: the audit's per-Surface section headers
# appear under Surface 5, AND the EXCLUDED verdict token is visible in
# the embedded table itself (not just the divergence summary).
assert "dedupe Surface 5 inlines audit per-item table on divergence" 'echo "$EX_HUMAN" | grep -q "Surface — Plugins"'
assert "dedupe Surface 5 inline table shows EXCLUDED verdict row" 'echo "$EX_HUMAN" | grep -E "^\s+EXCLUDED\b" >/dev/null'
assert "dedupe Surface 5 drops absolute-path footer pointing at audit bin" '! echo "$EX_HUMAN" | grep -q "Run /.*ai-kit-audit-ecosystem.sh"'

rm -rf "$EX_WORK"

print_summary_and_exit
