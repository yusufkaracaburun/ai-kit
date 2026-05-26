#!/usr/bin/env bash
# Integration test for /ai:docs-sync — dead-links section (v1).
#
# Covers (per #92 acceptance criteria):
#   - skill/command artefacts exist
#   - command discoverable
#   - broken-link fixture exits 1, reports both findings, names them correctly
#   - clean fixture exits 0
#   - HTML <a href>, bare URLs, anchor-only links, and code-fence links are NEVER counted
#   - anchor fragments do not invalidate a valid path (./file.md#section with existing file → pass)
#   - non-existent docs/ tree handled
#   - --skip-dead-links bypasses the section
#   - SKILL.md contains the locked "## Non-goals" section
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

DRIVER="$AIKIT/bin/ai-kit-docs-sync.sh"
DEAD_LINKS="$AIKIT/bin/ai-kit-docs-sync-dead-links.sh"
SKILL="$AIKIT/workflow/skills/docs-sync/SKILL.md"
COMMAND="$AIKIT/workflow/commands/docs-sync.md"
FIX_BROKEN="$AIKIT/tests/fixtures/docs-sync-dead-links"
FIX_CLEAN="$AIKIT/tests/fixtures/docs-sync-clean"

echo "=== artefacts-exist ==="
assert "driver script exists + executable" '[ -x "$DRIVER" ]'
assert "dead-links script exists + executable" '[ -x "$DEAD_LINKS" ]'
assert "SKILL.md exists" '[ -f "$SKILL" ]'
assert "command.md exists" '[ -f "$COMMAND" ]'
assert "broken-link fixture dir exists" '[ -d "$FIX_BROKEN" ]'
assert "clean fixture dir exists" '[ -d "$FIX_CLEAN" ]'

echo "=== skill-locks-non-goals ==="
assert "SKILL.md frontmatter mentions content drift" \
  'grep -iq "content[ -]drift" "$SKILL"'
assert "SKILL.md has a Non-goals section" \
  'grep -q "^## Non-goals" "$SKILL"'
for goal in "ADR-trigger detection" "TODO-completion" "Status-table drift" \
            "PII grep" "Structure-convention" "Code-comment-as-doc"; do
  assert "Non-goals lists '$goal'" \
    'grep -F -q "'"$goal"'" "$SKILL"'
done

echo "=== broken-link-fixture ==="
OUTPUT_BROKEN="$(bash "$DRIVER" "$FIX_BROKEN" --no-prompt 2>&1 || true)"
RC_BROKEN=$(bash "$DRIVER" "$FIX_BROKEN" --no-prompt >/dev/null 2>&1; echo $?)
assert "broken-link fixture exits 1" '[ "$RC_BROKEN" = "1" ]'
assert "report names docs/architecture.md" \
  'echo "$OUTPUT_BROKEN" | grep -q "docs/architecture.md"'
assert "report includes (relative) legacy-install.md finding" \
  'echo "$OUTPUT_BROKEN" | grep -F -q "legacy-install.md"'
assert "report includes (absolute) /missing-root.md finding" \
  'echo "$OUTPUT_BROKEN" | grep -F -q "/missing-root.md"'
assert "exactly 2 findings reported" \
  '[ "$(echo "$OUTPUT_BROKEN" | grep -c "missing path:")" = "2" ]'
assert "HTML <a href> link is NOT reported" \
  '! echo "$OUTPUT_BROKEN" | grep -F -q "html-broken.md"'
assert "bare URL is NOT reported" \
  '! echo "$OUTPUT_BROKEN" | grep -F -q "example.com/raw"'
assert "anchor-only link (#architecture) is NOT reported as broken" \
  '! echo "$OUTPUT_BROKEN" | grep -F -q "back to top"'
assert "image link (does-not-exist.png) is NOT reported" \
  '! echo "$OUTPUT_BROKEN" | grep -F -q "does-not-exist.png"'
assert "link inside code fence is NOT reported" \
  '! echo "$OUTPUT_BROKEN" | grep -F -q "this-does-not-exist.md"'

echo "=== clean-fixture ==="
OUTPUT_CLEAN="$(bash "$DRIVER" "$FIX_CLEAN" --no-prompt 2>&1)"
RC_CLEAN=$(bash "$DRIVER" "$FIX_CLEAN" --no-prompt >/dev/null 2>&1; echo $?)
assert "clean fixture exits 0" '[ "$RC_CLEAN" = "0" ]'
assert "clean fixture reports 0 broken" \
  'echo "$OUTPUT_CLEAN" | grep -q "0 broken links"'
assert "clean fixture summary all clean" \
  'echo "$OUTPUT_CLEAN" | grep -q "all sections clean"'

echo "=== anchor-with-valid-path ==="
# docs-sync-clean docs/setup.md anchor link `./docs/setup.md#anything` resolves
# to existing file even though anchor is not validated.
TMP_ANCHOR=$(mktemp -d)
trap 'rm -rf "$TMP_ANCHOR" "$TMP_SKIP" "$TMP_EMPTY"' EXIT
mkdir -p "$TMP_ANCHOR"
cat > "$TMP_ANCHOR/index.md" <<'MD'
[exists with anchor](./other.md#nope)
MD
echo "ok" > "$TMP_ANCHOR/other.md"
RC_ANCHOR=$(bash "$DRIVER" "$TMP_ANCHOR" --no-prompt >/dev/null 2>&1; echo $?)
assert "anchor on existing file does not break" '[ "$RC_ANCHOR" = "0" ]'

echo "=== skip-flag ==="
TMP_SKIP=$(mktemp -d)
cat > "$TMP_SKIP/broken.md" <<'MD'
[broken](./nope.md)
MD
RC_SKIP=$(bash "$DRIVER" "$TMP_SKIP" --skip-dead-links --no-prompt >/dev/null 2>&1; echo $?)
assert "--skip-dead-links bypasses the section (exits 0)" '[ "$RC_SKIP" = "0" ]'

echo "=== empty-project ==="
TMP_EMPTY=$(mktemp -d)
mkdir -p "$TMP_EMPTY"
RC_EMPTY=$(bash "$DRIVER" "$TMP_EMPTY" --no-prompt >/dev/null 2>&1; echo $?)
assert "project with no markdown files exits 0" '[ "$RC_EMPTY" = "0" ]'

print_summary_and_exit
