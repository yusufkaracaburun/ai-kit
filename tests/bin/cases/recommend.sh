#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== recommend-rules-cache ==="
# section: recommend-rules-cache
# Isolate the cache dir per-test so we don't clobber a real ~/.cache entry.
CACHE_XDG="$(mktemp -d)"
CACHE_HELPER="$AIKIT/bin/recommend-rules-cache.sh"

KEY_LARAVEL="$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" key "$AIKIT/tests/fixtures/architecture-laravel")"
KEY_FSD="$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" key "$AIKIT/tests/fixtures/architecture-fsd")"
KEY_LARAVEL2="$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" key "$AIKIT/tests/fixtures/architecture-laravel")"
assert "cache key is 64-char sha256 hex" '[[ "$KEY_LARAVEL" =~ ^[0-9a-f]{64}$ ]]'
assert "cache key stable across runs" '[ "$KEY_LARAVEL" = "$KEY_LARAVEL2" ]'
assert "cache key differs by stack" '[ "$KEY_LARAVEL" != "$KEY_FSD" ]'

set +e
XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL" >/dev/null 2>&1
MISS_EXIT=$?
set -e
assert "cache miss when empty" '[ "$MISS_EXIT" -ne 0 ]'

echo '{"candidates":[{"name":"laravel-boost","url":"x"}],"ts":1}' | \
  XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" write "$KEY_LARAVEL"
HIT_OUT="$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL")"
assert "cache hit after write" 'echo "$HIT_OUT" | grep -q "laravel-boost"'
assert "cache hit is valid JSON" 'echo "$HIT_OUT" | python3 -c "import json,sys; json.load(sys.stdin)"'

# Backdate the file past the TTL — should now miss.
CACHE_FILE="$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" path "$KEY_LARAVEL")"
touch -t 202001010000 "$CACHE_FILE"
set +e
XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL" >/dev/null 2>&1
STALE_EXIT=$?
set -e
assert "cache miss when older than TTL" '[ "$STALE_EXIT" -ne 0 ]'
# But a long --ttl recovers it.
assert "--ttl override revives stale entry" 'XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL" --ttl 999999 | grep -q "laravel-boost"'

# --no-cache short-circuits both directions.
set +e
XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL" --no-cache --ttl 999999 >/dev/null 2>&1
NC_EXIT=$?
set -e
assert "--no-cache forces miss" '[ "$NC_EXIT" -ne 0 ]'
echo '{"candidates":[]}' | XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" write "$KEY_LARAVEL" --no-cache
assert "--no-cache write is a no-op" 'XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" read "$KEY_LARAVEL" --ttl 999999 | grep -q "laravel-boost"'

# Invalid JSON must be rejected, not persisted.
set +e
echo 'not json' | XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" write "${KEY_LARAVEL}-bad" 2>/dev/null
BAD_EXIT=$?
set -e
assert "write rejects invalid JSON" '[ "$BAD_EXIT" -ne 0 ]'
assert "rejected JSON not persisted" '[ ! -f "$(XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" path "${KEY_LARAVEL}-bad")" ]'

# clear <key> wipes a single entry.
XDG_CACHE_HOME="$CACHE_XDG" "$CACHE_HELPER" clear "$KEY_LARAVEL"
assert "clear removes entry" '[ ! -f "$CACHE_FILE" ]'

rm -rf "$CACHE_XDG"


echo "=== recommend-rules ==="
# section: recommend-rules
REC_TMP=$(mktemp -d)
cp -R "$AIKIT/tests/fixtures/architecture-laravel/." "$REC_TMP/"
JSON_REC="$("$AIKIT/bin/recommend-rules.sh" "$REC_TMP" --json)"
assert "recommend: universal rule (git-hygiene) scored" 'echo "$JSON_REC" | grep -q "\"name\": \"git-hygiene\""'
assert "recommend: universal rule (context-discipline) scored" 'echo "$JSON_REC" | grep -q "\"name\": \"context-discipline\""'
assert "recommend: score is integer" 'echo "$JSON_REC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(isinstance(r[\"score\"], int) for r in d[\"recommendations\"])"'
assert "recommend: results sorted desc" 'echo "$JSON_REC" | python3 -c "import json,sys; d=json.load(sys.stdin); s=[r[\"score\"] for r in d[\"recommendations\"]]; assert s == sorted(s, reverse=True)"'
rm -rf "$REC_TMP"


echo "=== recommend-tools ==="
# section: recommend-tools
TOOLS_TMP=$(mktemp -d)
cp -R "$AIKIT/tests/fixtures/architecture-laravel/." "$TOOLS_TMP/"
touch "$TOOLS_TMP/pint.json" "$TOOLS_TMP/.env"
JSON_TOOLS="$("$AIKIT/bin/recommend-tools.sh" "$TOOLS_TMP" --json)"
assert "recommend-tools: context7 surfaced (laravel framework match)" 'echo "$JSON_TOOLS" | grep -q "\"name\": \"context7\""'
assert "recommend-tools: laravel-pint surfaced (file + framework)" 'echo "$JSON_TOOLS" | grep -q "\"name\": \"laravel-pint\""'
assert "recommend-tools: block-env-edits surfaced (.env present)" 'echo "$JSON_TOOLS" | grep -q "\"name\": \"block-env-edits\""'
assert "recommend-tools: score is integer" 'echo "$JSON_TOOLS" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(isinstance(r[\"score\"], int) for r in d[\"recommendations\"])"'
assert "recommend-tools: kind in {mcp,hook,plugin}" 'echo "$JSON_TOOLS" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(r[\"kind\"] in (\"mcp\",\"hook\",\"plugin\") for r in d[\"recommendations\"])"'
assert "recommend-tools: sorted desc by score" 'echo "$JSON_TOOLS" | python3 -c "import json,sys; d=json.load(sys.stdin); s=[r[\"score\"] for r in d[\"recommendations\"]]; assert s == sorted(s, reverse=True)"'
assert "recommend-tools: laravel-boost plugin surfaced (laravel framework match)" 'echo "$JSON_TOOLS" | grep -q "\"name\": \"laravel-boost\""'
assert "recommend-tools: claude-mem plugin surfaced (universal)" 'echo "$JSON_TOOLS" | grep -q "\"name\": \"claude-mem\""'

JSON_MCP="$("$AIKIT/bin/recommend-tools.sh" "$TOOLS_TMP" --json --kind mcp)"
assert "recommend-tools --kind mcp: only mcp" 'echo "$JSON_MCP" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(r[\"kind\"]==\"mcp\" for r in d[\"recommendations\"]) and len(d[\"recommendations\"])>0"'

JSON_HOOK="$("$AIKIT/bin/recommend-tools.sh" "$TOOLS_TMP" --json --kind hook)"
assert "recommend-tools --kind hook: only hooks" 'echo "$JSON_HOOK" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(r[\"kind\"]==\"hook\" for r in d[\"recommendations\"]) and len(d[\"recommendations\"])>0"'

JSON_PLUGIN="$("$AIKIT/bin/recommend-tools.sh" "$TOOLS_TMP" --json --kind plugin)"
assert "recommend-tools --kind plugin: only plugins" 'echo "$JSON_PLUGIN" | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(r[\"kind\"]==\"plugin\" for r in d[\"recommendations\"]) and len(d[\"recommendations\"])>0"'
rm -rf "$TOOLS_TMP"

EMPTY_TMP=$(mktemp -d)
JSON_EMPTY="$("$AIKIT/bin/recommend-tools.sh" "$EMPTY_TMP" --json)"
assert "recommend-tools empty stack: universal hooks still surfaced" 'echo "$JSON_EMPTY" | grep -q "\"name\": \"block-lockfile-edits\""'
assert "recommend-tools empty stack: universal plugins still surfaced" 'echo "$JSON_EMPTY" | grep -q "\"name\": \"claude-mem\""'
assert "recommend-tools empty stack: universal MCP (context7) still surfaced" 'echo "$JSON_EMPTY" | grep -q "\"name\": \"context7\""'
assert "recommend-tools empty stack: only universal MCPs surface (context7), no stack-specific MCPs" 'echo "$JSON_EMPTY" | python3 -c "import json,sys; d=json.load(sys.stdin); mcp_names = [r[\"name\"] for r in d[\"recommendations\"] if r[\"kind\"]==\"mcp\"]; assert mcp_names == [\"context7\"], f\"expected only context7, got {mcp_names}\""'
rm -rf "$EMPTY_TMP"

assert "recommend-tools: rejects unknown --kind" '! "$AIKIT/bin/recommend-tools.sh" "$AIKIT" --kind bogus >/dev/null 2>&1'

TMP_LINK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --link-all "$TMP_LINK"
assert "link-all .claude symlink" '[ -L "$TMP_LINK/.claude/skills" ]'
assert "link-all symlink" '[ -L "$TMP_LINK/.cursor/skills" ]'
rm -rf "$TMP_LINK"

TMP_MERGE=$(mktemp -d)
cp -R "$AIKIT/tests/fixtures/brownfield-custom-skills/.cursor" "$TMP_MERGE/"
"$AIKIT/bin/bootstrap-project.sh" --minimal --merge-skills "$TMP_MERGE"
assert "merge keeps custom skill" '[ -d "$TMP_MERGE/.cursor/skills/my-custom-skill" ] || [ -L "$TMP_MERGE/.cursor/skills/my-custom-skill" ]'
assert "merge adds setup" '[ -e "$TMP_MERGE/.cursor/skills/setup" ]'
assert "merge adds .claude/skills/setup" '[ -e "$TMP_MERGE/.claude/skills/setup" ]'
rm -rf "$TMP_MERGE"

TMP_NO_SK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-skills "$TMP_NO_SK"
assert "no-skills AGENTS.md" '[ -f "$TMP_NO_SK/AGENTS.md" ]'
assert "no-skills skips .claude/skills" '[ ! -e "$TMP_NO_SK/.claude/skills" ]'
assert "no-skills skips .agents/skills" '[ ! -e "$TMP_NO_SK/.agents/skills" ]'
assert "no-skills skips .cursor/skills" '[ ! -e "$TMP_NO_SK/.cursor/skills" ]'
rm -rf "$TMP_NO_SK"

TMP_NO_AG=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-agents --no-commands "$TMP_NO_AG"
assert "--no-agents skips .claude/agents" '[ ! -e "$TMP_NO_AG/.claude/agents" ]'
assert "--no-commands skips .claude/commands" '[ ! -e "$TMP_NO_AG/.claude/commands" ]'
assert "--no-commands skips .cursor/commands" '[ ! -e "$TMP_NO_AG/.cursor/commands" ]'
assert "no-agents/no-commands still links skills" '[ -d "$TMP_NO_AG/.claude/skills" ]'
rm -rf "$TMP_NO_AG"


print_summary_and_exit
