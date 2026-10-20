#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== companions-disambig ==="
# Section: companions-disambig
# Two companion tools both scaffold a "wiki" surface — graphify's AST wiki at
# graphify-out/wiki/ vs. llm-wiki's curated wiki at wiki/. Templates must
# name themselves uniquely and cross-reference the other to prevent the
# agent guessing which wiki the user means. See ai-kit GH issue #53.

GRAPHIFY_MD="$AIKIT/context/templates/companions/graphify.md"
LLMWIKI_README="$AIKIT/context/templates/companions/llm-wiki/README.md"
COMPANIONS_JSON="$AIKIT/standards/external/companions.json"
RECOMMEND_SKILL="$AIKIT/workflow/skills/recommend-tools/SKILL.md"

assert "graphify.md names its wiki 'graphify-wiki'" 'grep -q "graphify-wiki" "$GRAPHIFY_MD"'
assert "graphify.md cross-refs llm-wiki disambig" 'grep -q "llm-wiki" "$GRAPHIFY_MD"'

assert "llm-wiki/README.md names itself 'llm-wiki'" 'grep -q "llm-wiki" "$LLMWIKI_README"'
assert "llm-wiki/README.md cross-refs graphify-wiki disambig" 'grep -q "graphify-wiki" "$LLMWIKI_README"'

assert "companions.json graphify entry cross-refs llm-wiki" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); g=[r for r in d[\"recommendations\"] if r[\"name\"]==\"graphify\"][0]; sys.exit(0 if any(\"llm-wiki\" in str(c) for c in g[\"conflicts\"]) else 1)"'

assert "companions.json llm-wiki entry cross-refs graphify" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); l=[r for r in d[\"recommendations\"] if r[\"name\"]==\"llm-wiki\"][0]; sys.exit(0 if any(\"graphify\" in str(c) for c in l[\"conflicts\"]) else 1)"'

assert "recommend-tools SKILL emits disambig when both wikis present" \
  'grep -q "Two wikis present" "$RECOMMEND_SKILL"'

# rtk compacts Bash tool output; it must name graphify (input search) and
# caveman (output prose) so the agent does not treat them as one dimension.
assert "companions.json rtk entry cross-refs graphify and caveman" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); r=[x for x in d[\"recommendations\"] if x[\"name\"]==\"rtk\"][0]; sys.exit(0 if all(k in r[\"complements\"] for k in (\"graphify\",\"caveman\")) else 1)"'
assert "plugins-excluded.json no longer lists rtk" \
  'python3 -c "import json,sys; d=json.load(open(\"$AIKIT/standards/external/plugins-excluded.json\")); sys.exit(1 if any(e[\"name\"]==\"rtk\" for e in d[\"excluded\"]) else 0)"'
assert "recommend-tools SKILL wires rtk via rtk init -g" \
  'grep -q "rtk init -g" "$RECOMMEND_SKILL"'

# The OpenSEO plugin's .mcp.json points at the hosted app; a self-hoster who
# installs it as well registers a second openseo MCP.
assert "companions.json lists openseo" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); sys.exit(0 if any(x[\"name\"]==\"openseo\" for x in d[\"recommendations\"]) else 1)"'
assert "recommend-tools SKILL says the OpenSEO plugin is hosted only" \
  'grep -q "plugin is for hosted OpenSEO only" "$RECOMMEND_SKILL"'
assert "recommend-tools SKILL warns about the seo-audit name clash" \
  'grep -q "name clash" "$RECOMMEND_SKILL"'
assert "VETTING.md carries an openseo audit row" \
  'grep -q "openseo · category=seo" "$AIKIT/standards/external/VETTING.md"'

print_summary_and_exit
