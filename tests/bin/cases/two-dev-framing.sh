#!/usr/bin/env bash
# Merges we-pronouns.sh, setup-onboard-no-solo.sh, tdd-ship-review-required.sh,
# cold-pickup-rule.sh and autonomous-writer-reviewer.sh — five ai-kit issue #52
# prose-lint cases that all guard the 2-dev-default framing in shipped
# markdown. we-pronouns and setup-onboard-no-solo asserted the same "no
# team-size solo framing" invariant over two different directory scopes; they
# now share one widened target list instead of running it twice.
#
# Dropped on merge: five pure-bookkeeping assertions that only checked a
# markdown file mentions "#52" somewhere. Zero behavioural meaning — they
# break on any editorial rewrite of the cross-reference and guard nothing an
# editor could get wrong.
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== two-dev-framing: templates (we-pronouns) ==="
# Locks the 2-dev-default pronoun convention in templates that ship into
# downstream projects. ai-kit issue #52 + #64: templates default to "we" /
# imperative / 2nd-person, never first-person singular. Team-size "solo"
# strings are out — install-layout `setup_mode=solo-*` is the only allowed
# carrier of the token and stays per grill-Branch-1 (see issue #52).
#
# Scope: context/templates/docs/agents/ + context/templates/companions/.
# CHANGELOG.md / docs/spikes/ / context/prompts/ are explicitly out of scope.

TEMPLATES=(
  "$AIKIT/context/templates/docs/agents"
  "$AIKIT/context/templates/companions"
)
SETUP="$AIKIT/workflow/skills/setup/SKILL.md"
ONBOARD="$AIKIT/workflow/skills/onboard/SKILL.md"

# Build a single grep target list (only existing dirs).
TARGETS=()
for d in "${TEMPLATES[@]}"; do
  [ -d "$d" ] && TARGETS+=("$d")
done

# 1. No first-person singular pronouns.
#    Matches "I " / "I." / "I'" / line-start "I", and "my " / "me " / "myself".
#    Case-sensitive on "I" to avoid catching Roman-numeral / abbreviations.
assert "no first-person singular 'I ' pronoun in templates" \
  '! grep -rnE "(^| )I( |\.|,|\$|\x27)" "${TARGETS[@]}" 2>/dev/null | grep -v "^[[:space:]]*#" | grep .'

assert "no first-person singular 'my' / 'me' / 'myself' in templates" \
  '! grep -rniE "\b(my|me|mine|myself)\b" "${TARGETS[@]}" 2>/dev/null | grep .'

# 2. No team-size "solo" / "single dev" connotation — widened to also cover
#    the setup/onboard skills (formerly setup-onboard-no-solo.sh), which
#    assert the identical invariant over a different scope.
#    Whitelist: `setup_mode=solo-*` install-layout vocabulary (grill Branch 1).
#    Match lines containing solo/single-dev token AND NOT containing setup_mode.
WIDENED_TARGETS=("${TARGETS[@]}" "$SETUP" "$ONBOARD")
assert "no team-size 'solo' / 'single dev' string outside setup_mode= context (templates + setup/onboard skills)" \
  '! grep -rniE "\b(solo|single[ -]dev|single[ -]developer|single user)\b" "${WIDENED_TARGETS[@]}" 2>/dev/null | grep -viE "setup_mode|solo-(both|global)|\[solo-|solo-both\\|solo-global|\"setup_mode\"" | grep .'

# 3. Positive: at least one template should carry the 2-dev pronoun convention
#    explicitly so future authors know the rule. We accept this in either
#    a top-level templates README, an agent-stack template, or the companions
#    README. Asserting presence (not absence) here gives the test bite.
assert "2-dev pronoun convention documented in templates" \
  'grep -rqiE "(we (default|use|write)|two[- ]dev|2[- ]dev|second (dev|reviewer))" "${TARGETS[@]}" 2>/dev/null'

echo "=== two-dev-framing: setup/onboard skill regressions ==="
# ai-kit issue #62 (parent #52). Install-layout `setup_mode=solo-both|solo-global`
# is a different vocab axis (parent grill Branch 1) and must remain untouched.

assert "setup SKILL.md exists" '[ -f "$SETUP" ]'
assert "onboard SKILL.md exists" '[ -f "$ONBOARD" ]'

# Positive: install-layout vocabulary preserved (regression guard).
assert "setup SKILL.md: setup_mode=solo-both still documented (install layout preserved)" \
  'grep -q "solo-both" "$SETUP"'
assert "setup SKILL.md: setup_mode=solo-global still documented (install layout preserved)" \
  'grep -q "solo-global" "$SETUP"'

# Positive: rewritten lines mention the 2-dev framing.
assert "setup SKILL.md: 2-dev framing present where the 'informal solo' row was" \
  'grep -qiE "2[- ]dev|two[- ]dev|reviewer" "$SETUP"'

echo "=== two-dev-framing: tdd + ship review required ==="
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

assert "ship SKILL.md frames review-before-merge as precondition" \
  'grep -qiE "review.*precondition|precondition.*review|review must pass before|review must complete before" "$SHIP"'

# Negative: no surviving "review is optional" phrasing.
assert "tdd SKILL.md does not call review optional" \
  '! grep -qiE "review[^.]{0,60}(optional|recommended|if reviewers)" "$TDD"'
assert "ship SKILL.md does not call review optional" \
  '! grep -qiE "review[^.]{0,60}(optional|recommended|if reviewers)" "$SHIP"'

echo "=== two-dev-framing: cold-pickup rule ==="
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

# Issue #127: to-issues creates cold-readable issue bodies, but must not put
# work straight onto the autonomous queue without triage's Agent Brief comment.
assert "to-issues does not label issues ready-for-agent directly" \
  'grep -q "does not apply the .ready-for-agent. label directly" "$TOISSUES"'

assert "to-issues hands ready-for-agent promotion to triage" \
  'grep -q "triage.*Agent Brief.*ready-for-agent" "$TOISSUES"'

# Existing v1.14.1 cross-skill contract must remain intact (regression guard).
assert "triage retains atomic Agent Brief contract" \
  'grep -q "atomically with the label change" "$TRIAGE"'
assert "triage retains literal '\''## Agent Brief'\'' header rule" \
  'grep -q "## Agent Brief" "$TRIAGE"'

echo "=== two-dev-framing: autonomous writer/reviewer ==="
# ai-kit issue #68 (parent #52). autonomous SKILL.md must name the
# "agent = writer / human = reviewer" rule directly in its Trust model,
# not imply it via "never auto-merge".

AUTONOMOUS="$AIKIT/workflow/skills/autonomous/SKILL.md"

assert "autonomous SKILL.md exists" '[ -f "$AUTONOMOUS" ]'

assert "autonomous consumes triage's Agent Brief queue contract" \
  'grep -q "queue contract produced by .triage." "$AUTONOMOUS" && grep -q "## Agent Brief" "$AUTONOMOUS"'

assert "Trust model names the writer/reviewer rule explicitly" \
  'grep -qiE "writer.*reviewer|Agent is the writer" "$AUTONOMOUS"'

assert "Rule includes the solo-human caveat (single-contributor case)" \
  'grep -qiE "solo[- ]?human|one human contributor|single human" "$AUTONOMOUS"'

# Regression: the existing behavioral rules must remain intact.
assert "Trust model retains Never auto-merge rule" \
  'grep -q "Never auto-merge" "$AUTONOMOUS"'

assert "Trust model retains CI / branch-protection bypass ban" \
  'grep -q "Never bypass CI / branch protection" "$AUTONOMOUS"'

print_summary_and_exit
