#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== tdd-ship-review-required ==="
# Section: tdd-ship-review-required
# ai-kit issue #63 (parent #52). tdd + ship SKILL.md must label review as
# a non-optional phase, with explicit clause that the rule applies even
# when the project has one human contributor. No surviving language may
# imply review is optional.

TDD="$AIKIT/workflow/skills/tdd/SKILL.md"
SHIP="$AIKIT/workflow/skills/ship/SKILL.md"

assert "tdd SKILL.md exists" '[ -f "$TDD" ]'
assert "ship SKILL.md exists" '[ -f "$SHIP" ]'

assert "tdd SKILL.md has explicit Review (required) phase" \
  'grep -qE "Review \(required\)|Review — required|required Review" "$TDD"'

assert "tdd SKILL.md states the rule applies to single-human projects too" \
  'grep -qiE "one human contributor|single human|solo[- ]human" "$TDD"'

assert "tdd SKILL.md cross-refs parent #52" 'grep -qE "#52|issue 52" "$TDD"'

assert "ship SKILL.md frames review-before-merge as precondition" \
  'grep -qiE "review.*precondition|precondition.*review|review must pass before|review must complete before" "$SHIP"'

assert "ship SKILL.md cross-refs parent #52" 'grep -qE "#52|issue 52" "$SHIP"'

# Negative: no surviving "review is optional" phrasing.
assert "tdd SKILL.md does not call review optional" \
  '! grep -qiE "review[^.]{0,60}(optional|recommended|if reviewers)" "$TDD"'
assert "ship SKILL.md does not call review optional" \
  '! grep -qiE "review[^.]{0,60}(optional|recommended|if reviewers)" "$SHIP"'

print_summary_and_exit
