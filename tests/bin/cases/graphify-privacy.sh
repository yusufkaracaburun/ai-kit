#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== graphify-privacy ==="
# An unpinned graphify backend sends files to whichever provider's API key is
# set (#220), so the glue pins claude-cli and the starter keeps memory out.

GRAPHIFYIGNORE="$AIKIT/workflow/context/templates/companions/graphifyignore"
RECOMMEND_SKILL="$AIKIT/workflow/skills/recommend-tools/SKILL.md"
GRAPHIFY_COMPANION="$AIKIT/workflow/context/templates/companions/graphify.md"

assert "graphifyignore starter excludes .agents/memory/" \
  'grep -qx "\.agents/memory/" "$GRAPHIFYIGNORE"'
assert "recommend-tools pins the graphify backend to claude-cli" \
  'grep -q "graphify \. --backend claude-cli" "$RECOMMEND_SKILL"'
assert "docs-sync graph-fresh rebuild hint pins claude-cli" \
  'grep -q "graphify \. --backend claude-cli" "$AIKIT/workflow/bin/ai-kit-docs-sync-graph-fresh.sh"'

assert "graphify companion block pins claude-cli for the first run" \
  'grep -q "graphify \. --backend claude-cli" "$GRAPHIFY_COMPANION"'

print_summary_and_exit
