#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== autonomous-writer-reviewer ==="
# Section: autonomous-writer-reviewer
# ai-kit issue #68 (parent #52). autonomous SKILL.md must name the
# "agent = writer / human = reviewer" rule directly in its Trust model,
# not imply it via "never auto-merge".

SKILL="$AIKIT/workflow/skills/autonomous/SKILL.md"

assert "autonomous SKILL.md exists" '[ -f "$SKILL" ]'

assert "Trust model names the writer/reviewer rule explicitly" \
  'grep -qiE "writer.*reviewer|Agent is the writer" "$SKILL"'

assert "Rule includes the solo-human caveat (single-contributor case)" \
  'grep -qiE "solo[- ]?human|one human contributor|single human" "$SKILL"'

assert "Rule cross-refs parent #52" 'grep -qE "issue #52|#52" "$SKILL"'

# Regression: the existing behavioral rules must remain intact.
assert "Trust model retains Never auto-merge rule" \
  'grep -q "Never auto-merge" "$SKILL"'

assert "Trust model retains CI / branch-protection bypass ban" \
  'grep -q "Never bypass CI / branch protection" "$SKILL"'

print_summary_and_exit
