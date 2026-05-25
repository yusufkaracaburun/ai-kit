#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== cold-pickup-rule ==="
# Section: cold-pickup-rule
# ai-kit issue #65 (parent #52). triage + to-issues must state the
# Second-dev cold-pickup rule as a first-class invariant, not implicit via
# the cross-skill Agent Brief contract.

TRIAGE="$AIKIT/workflow/skills/triage/SKILL.md"
TOISSUES="$AIKIT/workflow/skills/to-issues/SKILL.md"

assert "triage SKILL.md exists" '[ -f "$TRIAGE" ]'
assert "to-issues SKILL.md exists" '[ -f "$TOISSUES" ]'

# Rule must be named explicitly in both.
assert "triage SKILL.md names the Second-dev cold-pickup rule" \
  'grep -qiE "second[- ]dev cold[- ]?pickup|cold[- ]?pickup rule" "$TRIAGE"'

assert "to-issues SKILL.md names the Second-dev cold-pickup rule" \
  'grep -qiE "second[- ]dev cold[- ]?pickup|cold[- ]?pickup rule" "$TOISSUES"'

# Rationale must cross-ref parent #52.
assert "triage SKILL.md cross-refs parent #52" 'grep -qE "#52|ai-kit issue 52" "$TRIAGE"'
assert "to-issues SKILL.md cross-refs parent #52" 'grep -qE "#52|ai-kit issue 52" "$TOISSUES"'

# Existing v1.14.1 cross-skill contract must remain intact (regression guard).
assert "triage retains atomic Agent Brief contract" \
  'grep -q "atomically with the label change" "$TRIAGE"'
assert "triage retains literal '\''## Agent Brief'\'' header rule" \
  'grep -q "## Agent Brief" "$TRIAGE"'

print_summary_and_exit
