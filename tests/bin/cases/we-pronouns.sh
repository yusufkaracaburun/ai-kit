#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== we-pronouns ==="
# Section: we-pronouns
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

# 2. No team-size "solo" / "single dev" connotation.
#    Whitelist: `setup_mode=solo-*` install-layout vocabulary (grill Branch 1).
#    Match lines containing solo/single-dev token AND NOT containing setup_mode.
assert "no team-size 'solo' / 'single dev' string outside setup_mode= context" \
  '! grep -rniE "\b(solo|single[ -]dev|single[ -]developer|single user)\b" "${TARGETS[@]}" 2>/dev/null | grep -viE "setup_mode|solo-(both|global)|\[solo-" | grep .'

# 3. Positive: at least one template should carry the 2-dev pronoun convention
#    explicitly so future authors know the rule. We accept this in either
#    a top-level templates README, an agent-stack template, or the companions
#    README. Asserting presence (not absence) here gives the test bite.
assert "2-dev pronoun convention documented in templates" \
  'grep -rqiE "(we (default|use|write)|two[- ]dev|2[- ]dev|second (dev|reviewer))" "${TARGETS[@]}" 2>/dev/null'

print_summary_and_exit
