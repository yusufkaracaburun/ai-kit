#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== setup-rtk-graphify-offer ==="
# /ai:setup Branch 2e offers rtk on every setup and graphify only on large
# repos (#219); the recommend-tools graphify glue covers refresh and stack
# fit (#220).

COMPANIONS_JSON="$AIKIT/standards/external/companions.json"
SETUP_SKILL="$AIKIT/workflow/skills/setup/SKILL.md"
RECOMMEND_SKILL="$AIKIT/workflow/skills/recommend-tools/SKILL.md"

BRANCH_2E=$(awk '/^### Branch 2e/{f=1;next} /^### /{f=0} f' "$SETUP_SKILL")
GRAPHIFY_WIRE=$(awk '/^\*\*graphify:\*\*/{f=1;next} /^\*\*caveman:\*\*/{f=0} f' "$RECOMMEND_SKILL")
GRAPHIFY_FIT=$(grep '^- \*\*graphify\*\*' "$RECOMMEND_SKILL")

assert "companions.json marks rtk universal" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); r=[x for x in d[\"recommendations\"] if x[\"name\"]==\"rtk\"][0]; sys.exit(0 if r.get(\"universal\") is True else 1)"'
assert "Branch 2e skips rtk when its hook is already registered" \
  'echo "$BRANCH_2E" | grep -qF "rtk hook|rtk-rewrite"'
assert "Branch 2e rtk prompt says rtk init -g patches ~/.claude/settings.json" \
  'echo "$BRANCH_2E" | grep -q "rtk init -g.*~/.claude/settings.json"'

assert "Branch 2e gates graphify on roughly 500 code files" \
  'echo "$BRANCH_2E" | grep -q "500 code files"'
assert "Branch 2e graphify points at the recommend-tools glue" \
  'echo "$BRANCH_2E" | grep -q "recommend-tools/SKILL.md"'
assert "Branch 2e graphify first build pins claude-cli" \
  'echo "$BRANCH_2E" | grep -qF "graphify . --backend claude-cli"'
assert "Branch 2e graphify count applies the stack-fit gate" \
  'echo "$BRANCH_2E" | grep -q "\.astro"'

assert "recommend-tools graphify glue offers graphify hook install" \
  'echo "$GRAPHIFY_WIRE" | grep -q "graphify hook install"'
assert "graphify hook install described as post-commit/post-checkout" \
  'echo "$GRAPHIFY_WIRE" | grep -q "post-commit.*post-checkout"'

assert "graphify fit rule rates weak on unparsed languages (.astro named)" \
  'echo "$GRAPHIFY_FIT" | grep -q "\.astro"'

RTK_FIT=$(grep '^- \*\*rtk\*\*' "$RECOMMEND_SKILL")
RTK_WIRE=$(awk '/^\*\*rtk:\*\*/{f=1;next} /^### /{f=0} f' "$RECOMMEND_SKILL")
assert "rtk fit rule checks the prompted marker before re-asking" \
  'echo "$RTK_FIT" | grep -q "branches.universal_companions_prompted"'
assert "graphify fit rule checks the prompted marker before re-asking" \
  'echo "$GRAPHIFY_FIT" | grep -q "branches.universal_companions_prompted"'
assert "Phase 3 rtk step 1 defers to the marker check" \
  'echo "$RTK_WIRE" | grep "^1\." | grep -q "marker"'
assert "companions.json rtk base tier is auto_prompted via Branch 2e" \
  'python3 -c "import json,sys; d=json.load(open(\"$COMPANIONS_JSON\")); r=[x for x in d[\"recommendations\"] if x[\"name\"]==\"rtk\"][0]; t=r[\"tiers\"][0]; sys.exit(0 if t.get(\"auto_prompted\") is True and t[\"wired_via\"].startswith(\"workflow/skills/setup/SKILL.md Branch 2e + \") and r[\"install\"].get(\"default_state\")==\"auto-prompted\" else 1)"'

print_summary_and_exit
