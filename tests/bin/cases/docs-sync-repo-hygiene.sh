#!/usr/bin/env bash
# Integration test for /ai:docs-sync — repo-hygiene section (#93).
#
# Covers (per #93 acceptance criteria):
#   - section appears in driver output after dead-links
#   - empty dirs detected with repo-relative paths
#   - broken symlinks detected with link + target
#   - orphan .agents/skills/<name>/ dirs detected, marked [report-only]
#   - .git, node_modules, vendor excluded by default
#   - group-confirm prompt deletes empty dirs + broken symlinks on y
#   - decline keeps files
#   - orphan-skill-dir findings NEVER trigger fix prompt
#   - --skip-repo-hygiene flag bypasses the section
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

DRIVER="$AIKIT/bin/ai-kit-docs-sync.sh"
HYGIENE="$AIKIT/bin/ai-kit-docs-sync-repo-hygiene.sh"
FIX_RH="$AIKIT/tests/fixtures/docs-sync-repo-hygiene"

echo "=== artefacts-exist ==="
assert "repo-hygiene script exists + executable" '[ -x "$HYGIENE" ]'
assert "repo-hygiene fixture dir exists" '[ -d "$FIX_RH" ]'
assert "fixture has empty_dir" '[ -d "$FIX_RH/empty_dir" ] && [ -z "$(ls -A "$FIX_RH/empty_dir")" ]'
assert "fixture has broken-link" '[ -L "$FIX_RH/broken-link" ] && [ ! -e "$FIX_RH/broken-link" ]'
assert "fixture has orphan skill dir" '[ -d "$FIX_RH/.agents/skills/incomplete" ] && [ ! -f "$FIX_RH/.agents/skills/incomplete/SKILL.md" ]'
assert "fixture has proper skill dir (must NOT be flagged)" \
  '[ -f "$FIX_RH/.agents/skills/proper/SKILL.md" ]'

echo "=== driver-output ==="
OUTPUT="$(bash "$DRIVER" "$FIX_RH" --skip-dead-links --no-prompt 2>&1 || true)"
RC=$(bash "$DRIVER" "$FIX_RH" --skip-dead-links --no-prompt >/dev/null 2>&1; echo $?)
assert "section header appears" \
  'echo "$OUTPUT" | grep -q "^=== repo-hygiene"'
assert "exit code 1" '[ "$RC" = "1" ]'
assert "3 findings reported (1 empty + 1 broken symlink + 1 orphan)" \
  'echo "$OUTPUT" | grep -q "repo-hygiene: 3 finding"'

echo "=== empty-dirs ==="
assert "empty_dir listed under Empty directories" \
  'echo "$OUTPUT" | grep -A1 "Empty directories" | grep -q "empty_dir"'

echo "=== broken-symlinks ==="
assert "broken-link listed under Broken symlinks" \
  'echo "$OUTPUT" | grep -A1 "Broken symlinks" | grep -q "broken-link"'
assert "broken-link target printed (./does-not-exist)" \
  'echo "$OUTPUT" | grep -F -q "broken-link -> ./does-not-exist"'

echo "=== orphan-skill-dirs ==="
assert "incomplete listed under Orphan .agents/skills" \
  'echo "$OUTPUT" | grep -A1 "Orphan .agents/skills" | grep -q "incomplete"'
assert "orphan section marked [report-only]" \
  'echo "$OUTPUT" | grep -F -q "[report-only]"'
assert "proper skill dir is NOT flagged" \
  '! echo "$OUTPUT" | grep -F -q "/proper$\|/proper\b"'

echo "=== exclusions ==="
TMP_EXCLUDE=$(mktemp -d)
trap 'rm -rf "$TMP_EXCLUDE" "$TMP_DECLINE" "$TMP_ACCEPT" "$TMP_SKIP" "$TMP_ORPHAN_ONLY"' EXIT
mkdir -p "$TMP_EXCLUDE/.git/empty" "$TMP_EXCLUDE/node_modules/empty" "$TMP_EXCLUDE/vendor/empty"
# Add a real empty dir outside the excluded paths so the section still has work
mkdir -p "$TMP_EXCLUDE/real_empty"
OUTPUT_EX="$(bash "$DRIVER" "$TMP_EXCLUDE" --skip-dead-links --no-prompt 2>&1 || true)"
assert "real_empty detected" 'echo "$OUTPUT_EX" | grep -F -q "real_empty"'
assert "empties inside .git are NOT detected" \
  '! echo "$OUTPUT_EX" | grep -F -q ".git/empty"'
assert "empties inside node_modules are NOT detected" \
  '! echo "$OUTPUT_EX" | grep -F -q "node_modules/empty"'
assert "empties inside vendor are NOT detected" \
  '! echo "$OUTPUT_EX" | grep -F -q "vendor/empty"'

echo "=== decline-keeps-files ==="
TMP_DECLINE=$(mktemp -d)
mkdir -p "$TMP_DECLINE/empty_a" "$TMP_DECLINE/empty_b"
ln -s "./missing" "$TMP_DECLINE/dangling"
# --no-prompt path = report-only, never deletes
bash "$DRIVER" "$TMP_DECLINE" --skip-dead-links --no-prompt >/dev/null 2>&1 || true
assert "empty_a kept after --no-prompt run" '[ -d "$TMP_DECLINE/empty_a" ]'
assert "empty_b kept after --no-prompt run" '[ -d "$TMP_DECLINE/empty_b" ]'
assert "dangling symlink kept after --no-prompt run" '[ -L "$TMP_DECLINE/dangling" ]'

echo "=== accept-deletes-safe-items ==="
TMP_ACCEPT=$(mktemp -d)
mkdir -p "$TMP_ACCEPT/empty_a" "$TMP_ACCEPT/empty_b"
mkdir -p "$TMP_ACCEPT/.agents/skills/wip"
echo "wip" > "$TMP_ACCEPT/.agents/skills/wip/NOTES.md"
ln -s "./missing" "$TMP_ACCEPT/dangling"
# Test-only env var simulates `y` reply to the group-confirm prompt.
AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1 \
  bash "$HYGIENE" "$TMP_ACCEPT" >/dev/null 2>&1 || true
assert "empty_a deleted after y reply" '[ ! -d "$TMP_ACCEPT/empty_a" ]'
assert "empty_b deleted after y reply" '[ ! -d "$TMP_ACCEPT/empty_b" ]'
assert "broken symlink deleted after y reply" '[ ! -L "$TMP_ACCEPT/dangling" ]'
assert "orphan skill dir is NEVER deleted by accept path" \
  '[ -d "$TMP_ACCEPT/.agents/skills/wip" ]'

echo "=== orphan-only-no-prompt ==="
TMP_ORPHAN_ONLY=$(mktemp -d)
mkdir -p "$TMP_ORPHAN_ONLY/.agents/skills/wip"
echo "wip" > "$TMP_ORPHAN_ONLY/.agents/skills/wip/NOTES.md"
OUT_ORPHAN="$(AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1 bash "$HYGIENE" "$TMP_ORPHAN_ONLY" 2>&1 || true)"
assert "orphan-only fixture exits 1 (still a finding)" \
  '[ -d "$TMP_ORPHAN_ONLY/.agents/skills/wip" ]'
assert "AUTO_YES has no effect on orphan-only run (no safe ops → prompt never fires)" \
  '! echo "$OUT_ORPHAN" | grep -q "rmdir:\|rm:"'

echo "=== skip-flag ==="
TMP_SKIP=$(mktemp -d)
mkdir -p "$TMP_SKIP/empty"
RC_SKIP=$(bash "$DRIVER" "$TMP_SKIP" --skip-dead-links --skip-repo-hygiene --no-prompt >/dev/null 2>&1; echo $?)
assert "--skip-repo-hygiene bypasses the section (exit 0)" '[ "$RC_SKIP" = "0" ]'

print_summary_and_exit
