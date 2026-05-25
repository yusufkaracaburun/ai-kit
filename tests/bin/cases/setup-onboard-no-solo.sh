#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== setup-onboard-no-solo ==="
# Section: setup-onboard-no-solo
# ai-kit issue #62 (parent #52). Two skill files carried the only surviving
# team-size "solo" assumptions in the workflow/ surface. Lock them clean.
# Install-layout `setup_mode=solo-both|solo-global` is a different vocab
# axis (parent grill Branch 1) and must remain untouched.

SETUP="$AIKIT/workflow/skills/setup/SKILL.md"
ONBOARD="$AIKIT/workflow/skills/onboard/SKILL.md"

assert "setup SKILL.md exists" '[ -f "$SETUP" ]'
assert "onboard SKILL.md exists" '[ -f "$ONBOARD" ]'

# No team-size "solo" token in setup SKILL.md outside `setup_mode=` or the
# `solo-both|solo-global` install-layout vocabulary.
assert "setup SKILL.md: no team-size 'solo' string outside install-layout" \
  '! grep -niE "\bsolo\b" "$SETUP" 2>/dev/null | grep -viE "setup_mode|solo-(both|global)|solo-both\|solo-global|\"setup_mode\"" | grep .'

# Onboard has no setup_mode= references — any 'solo' there is team-size.
assert "onboard SKILL.md: no team-size 'solo' string anywhere" \
  '! grep -niE "\bsolo\b" "$ONBOARD" 2>/dev/null | grep .'

# Positive: install-layout vocabulary preserved (regression guard).
assert "setup SKILL.md: setup_mode=solo-both still documented (install layout preserved)" \
  'grep -q "solo-both" "$SETUP"'
assert "setup SKILL.md: setup_mode=solo-global still documented (install layout preserved)" \
  'grep -q "solo-global" "$SETUP"'

# Positive: rewritten lines mention the 2-dev framing.
assert "setup SKILL.md: 2-dev framing present where the 'informal solo' row was" \
  'grep -qiE "2[- ]dev|two[- ]dev|reviewer" "$SETUP"'

print_summary_and_exit
