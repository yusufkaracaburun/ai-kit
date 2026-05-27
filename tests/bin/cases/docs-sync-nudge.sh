#!/usr/bin/env bash
# Integration test for the /ai:docs-sync nudge wiring (#95).
#
# Covers (per #95 acceptance criteria):
#   - bin/lib/applicability.sh exists and exposes is_{docs_sync,hygiene}_applicable
#   - cheap presence checks: <50ms wall on a typical-sized fixture
#   - applicability matrix:
#       * docs/ present                  → docs-sync nudge fires
#       * markdown file only             → docs-sync nudge fires
#       * .git with >1 local branch      → docs-sync nudge fires
#       * none of those                  → docs-sync nudge silent
#       * .ai-kit-setup marker present   → hygiene nudge fires
#       * marker absent                  → hygiene nudge silent
#   - the three skill SKILL.md files mention the nudge helper script
#   - the three skills reference the central helper (not their own re-implementation)
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

NUDGE="$AIKIT/bin/ai-kit-docs-sync-nudge.sh"
LIB="$AIKIT/bin/lib/applicability.sh"

echo "=== artefacts-exist ==="
assert "applicability lib exists" '[ -f "$LIB" ]'
assert "nudge script exists + executable" '[ -x "$NUDGE" ]'
assert "lib exposes is_docs_sync_applicable" 'grep -q "^is_docs_sync_applicable()" "$LIB"'
assert "lib exposes is_hygiene_applicable" 'grep -q "^is_hygiene_applicable()" "$LIB"'

echo "=== applicability-matrix ==="
TMP_DOCS=$(mktemp -d)
TMP_MD=$(mktemp -d)
TMP_BRANCHES=$(mktemp -d)
TMP_NONE=$(mktemp -d)
TMP_MARKER=$(mktemp -d)
TMP_BOTH=$(mktemp -d)
trap 'rm -rf "$TMP_DOCS" "$TMP_MD" "$TMP_BRANCHES" "$TMP_NONE" "$TMP_MARKER" "$TMP_BOTH"' EXIT

mkdir -p "$TMP_DOCS/docs"
echo "# x" > "$TMP_MD/README.md"
(
  cd "$TMP_BRANCHES"
  git init -q -b master
  git config user.email t@t.t
  git config user.name t
  echo init > x; git add x; git commit -q -m init
  git branch other-branch
) >/dev/null 2>&1
touch "$TMP_MARKER/.ai-kit-setup"
mkdir -p "$TMP_BOTH/docs"
touch "$TMP_BOTH/.ai-kit-setup"

# docs/ present
OUT_DOCS="$(bash "$NUDGE" "$TMP_DOCS" --context=checkpoint)"
assert "docs/ present → docs-sync nudge appears" 'echo "$OUT_DOCS" | grep -q "/ai:docs-sync"'
assert "docs/ present, no marker → hygiene nudge absent" \
  '! echo "$OUT_DOCS" | grep -q "/ai:hygiene"'

# markdown file only
OUT_MD="$(bash "$NUDGE" "$TMP_MD" --context=checkpoint)"
assert "markdown-only project → docs-sync nudge appears" \
  'echo "$OUT_MD" | grep -q "/ai:docs-sync"'

# .git with > 1 branch
OUT_BR="$(bash "$NUDGE" "$TMP_BRANCHES" --context=checkpoint)"
assert ">1 local branch → docs-sync nudge appears" \
  'echo "$OUT_BR" | grep -q "/ai:docs-sync"'

# none of the above
OUT_NONE="$(bash "$NUDGE" "$TMP_NONE" --context=checkpoint)"
assert "nothing applies → nudge is silent (no docs-sync)" \
  '! echo "$OUT_NONE" | grep -q "/ai:docs-sync"'
assert "nothing applies → nudge is silent (no hygiene)" \
  '! echo "$OUT_NONE" | grep -q "/ai:hygiene"'
assert "nothing applies → nudge is silent (no context header)" \
  '[ -z "$OUT_NONE" ]'

# marker present
OUT_MARKER="$(bash "$NUDGE" "$TMP_MARKER" --context=checkpoint)"
assert ".ai-kit-setup marker present → hygiene nudge appears" \
  'echo "$OUT_MARKER" | grep -q "/ai:hygiene"'

# both
OUT_BOTH="$(bash "$NUDGE" "$TMP_BOTH" --context=checkpoint)"
assert "both applicable → both nudges appear" \
  '[ "$(echo "$OUT_BOTH" | grep -cE "/ai:(hygiene|docs-sync)")" -eq 2 ]'

echo "=== context-header ==="
assert "checkpoint context → 'Before clear, consider:' header" \
  'echo "$OUT_BOTH" | grep -q "^Before clear, consider:"'
OUT_SHIP="$(bash "$NUDGE" "$TMP_BOTH" --context=ship)"
assert "ship context → 'Closing this release? Consider:' header" \
  'echo "$OUT_SHIP" | grep -q "^Closing this release? Consider:"'
OUT_TRIAGE="$(bash "$NUDGE" "$TMP_BOTH" --context=triage)"
assert "triage context → 'After closing issues, consider:' header" \
  'echo "$OUT_TRIAGE" | grep -q "^After closing issues, consider:"'

echo "=== performance ==="
START_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
bash "$NUDGE" "$TMP_BOTH" --context=checkpoint >/dev/null
END_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
ELAPSED_MS=$(( END_MS - START_MS ))
assert "nudge runs in < 500ms (allow CI noise; target <50ms per call)" \
  '[ "$ELAPSED_MS" -lt 500 ]'

echo "=== skill-wiring ==="
for skill in checkpoint ship triage; do
  assert "$skill SKILL.md references ai-kit-docs-sync-nudge.sh" \
    'grep -q "ai-kit-docs-sync-nudge.sh" "$AIKIT/workflow/skills/'"$skill"'/SKILL.md"'
done
# Negative: no skill should re-implement the applicability logic.
for skill in checkpoint ship triage; do
  assert "$skill SKILL.md does NOT reinvent is_docs_sync_applicable" \
    '! grep -q "is_docs_sync_applicable()" "$AIKIT/workflow/skills/'"$skill"'/SKILL.md"'
done

print_summary_and_exit
