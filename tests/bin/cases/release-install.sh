#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== release-sh ==="
# section: release-sh
# Dry-run with prepared notes — script must not write anything.
TMP_NOTES="$(mktemp)"
echo "test entry body" > "$TMP_NOTES"
set +e
OUT_REL="$("$AIKIT/bin/release.sh" 9.9.9 --notes-file="$TMP_NOTES" --dry-run 2>&1)"
REL_EXIT=$?
set -e
assert "release: dry-run exits 0" '[ "$REL_EXIT" -eq 0 ]'
assert "release: dry-run announces version" 'echo "$OUT_REL" | grep -q "Would write VERSION = 9.9.9"'
assert "release: dry-run mentions tag" 'echo "$OUT_REL" | grep -q "Would tag: v9.9.9"'

set +e
OUT_BAD="$("$AIKIT/bin/release.sh" notsemver --dry-run 2>&1)"
BAD_EXIT=$?
set -e
assert "release: rejects non-semver" '[ "$BAD_EXIT" -ne 0 ]'

# Same version should be rejected.
CURRENT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"
set +e
OUT_SAME="$("$AIKIT/bin/release.sh" "$CURRENT_VERSION" --notes-file="$TMP_NOTES" --dry-run 2>&1)"
SAME_EXIT=$?
set -e
assert "release: rejects same version" '[ "$SAME_EXIT" -ne 0 ]'
assert "release: --no-tag dry-run skips tag mention" '! "$AIKIT/bin/release.sh" 9.9.8 --notes-file="$TMP_NOTES" --no-tag --dry-run 2>&1 | grep -q "Would tag"'

rm -f "$TMP_NOTES"


echo "=== install-sh ==="
# section: install-sh
# Help text
OUT_INSTALL_HELP="$("$AIKIT/install.sh" --help 2>&1)"
assert "install: help text" 'echo "$OUT_INSTALL_HELP" | grep -q "ai-kit installer"'
assert "install: lists --no-global" 'echo "$OUT_INSTALL_HELP" | grep -q -- "--no-global"'

# Clone from local repo with --no-global (end-to-end without touching ~/.claude).
TMP_HOME_INSTALL="$(mktemp -d)"
TMP_DIR_INSTALL="$TMP_HOME_INSTALL/.local/share/ai-kit"
HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --repo="$AIKIT" --dir="$TMP_DIR_INSTALL" --no-global --quiet
assert "install: clones into target dir" '[ -f "$TMP_DIR_INSTALL/VERSION" ]'
assert "install: writes ~/.config/ai-kit/root" '[ -f "$TMP_HOME_INSTALL/.config/ai-kit/root" ]'
assert "install: --no-global skips ~/.claude/skills" '[ ! -d "$TMP_HOME_INSTALL/.claude/skills" ]'

# Idempotent rerun — should detect existing install, not re-clone.
OUT_RERUN="$(HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --repo="$AIKIT" --dir="$TMP_DIR_INSTALL" --no-global 2>&1)"
assert "install: rerun detects existing" 'echo "$OUT_RERUN" | grep -q "already installed"'

# Refuse to clobber a non-aikit directory.
BAD_DIR_INSTALL="$(mktemp -d)"
touch "$BAD_DIR_INSTALL/foo.txt"
set +e
OUT_BAD="$(HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --dir="$BAD_DIR_INSTALL" --no-global 2>&1)"
BAD_EXIT=$?
set -e
assert "install: refuses to clobber non-aikit dir" '[ "$BAD_EXIT" -ne 0 ] && echo "$OUT_BAD" | grep -q "not an ai-kit clone"'

# Unknown flag exits 2.
set +e
"$AIKIT/install.sh" --bogus 2>/dev/null
INSTALL_BAD_FLAG_EXIT=$?
set -e
assert "install: unknown flag exits 2" '[ "$INSTALL_BAD_FLAG_EXIT" -eq 2 ]'

rm -rf "$TMP_HOME_INSTALL" "$BAD_DIR_INSTALL"


echo "=== ai-kit-root ==="
# section: ai-kit-root
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/ai-kit-root.sh"
ROOT_SCRIPT="$(resolve_ai_kit_root "$AIKIT/bin")"
assert "resolves from script path" '[ "$ROOT_SCRIPT" = "$AIKIT" ]'

TMP_HOME=$(mktemp -d)
export AI_KIT_ROOT=""
HOME="$TMP_HOME" write_ai_kit_root_config "$AIKIT"
ROOT_CFG="$(HOME="$TMP_HOME" resolve_ai_kit_root "")"
assert "resolves from config file" '[ "$ROOT_CFG" = "$AIKIT" ]'

export AI_KIT_ROOT="$AIKIT"
ROOT_ENV="$(resolve_ai_kit_root "")"
assert "resolves from AI_KIT_ROOT env" '[ "$ROOT_ENV" = "$AIKIT" ]'
unset AI_KIT_ROOT
rm -rf "$TMP_HOME"

CLI_OUT="$("$AIKIT/bin/ai-kit-root.sh")"
assert "ai-kit-root.sh CLI" '[ "$CLI_OUT" = "$AIKIT" ]'


echo "=== ai-kit-which ==="
# section: ai-kit-which
# Force the resolver to use the working repo, not whichever install is recorded
# in ~/.config/ai-kit/root. Tests assert against the in-repo skill set.
export AI_KIT_ROOT="$AIKIT"

# --list shows all skills with descriptions.
OUT_WHICH_LIST="$("$AIKIT/bin/ai-kit-which.sh" --list)"
assert "which --list has header" 'echo "$OUT_WHICH_LIST" | head -1 | grep -q "SKILL"'
WHICH_LIST_ROWS="$(echo "$OUT_WHICH_LIST" | tail -n +3 | wc -l | tr -d ' ')"
assert "which --list shows all 35 skills" '[ "$WHICH_LIST_ROWS" -eq 35 ]'

# --explain dumps the SKILL.md.
OUT_WHICH_EXP="$("$AIKIT/bin/ai-kit-which.sh" --explain ship)"
assert "which --explain ship shows frontmatter" 'echo "$OUT_WHICH_EXP" | grep -q "^name: ship$"'

set +e
"$AIKIT/bin/ai-kit-which.sh" --explain nonexistent-skill >/dev/null 2>&1
WHICH_BAD_EXIT=$?
set -e
assert "which --explain unknown exits non-zero" '[ "$WHICH_BAD_EXIT" -ne 0 ]'

# Free-text recommendations: each priority intent must surface its skill at rank 1.
OUT_WHICH_PRD="$("$AIKIT/bin/ai-kit-which.sh" "I want to write a PRD for the new feature")"
assert "which: PRD intent -> to-prd at rank 1" 'echo "$OUT_WHICH_PRD" | grep -q "^1\. /ai:to-prd"'

OUT_WHICH_TDD="$("$AIKIT/bin/ai-kit-which.sh" "I want to write tests first using red-green-refactor")"
assert "which: TDD intent -> tdd at rank 1" 'echo "$OUT_WHICH_TDD" | grep -q "^1\. /ai:tdd"'

OUT_WHICH_SHIP="$("$AIKIT/bin/ai-kit-which.sh" "deploy to production and write release notes")"
assert "which: ship intent -> ship at rank 1" 'echo "$OUT_WHICH_SHIP" | grep -q "^1\. /ai:ship"'

OUT_WHICH_REVIEW="$("$AIKIT/bin/ai-kit-which.sh" "review my code before merging")"
assert "which: review intent -> review at rank 1" 'echo "$OUT_WHICH_REVIEW" | grep -q "^1\. /ai:review"'

# Gibberish intent returns the no-match message instead of a false positive.
set +e
OUT_WHICH_NONE="$("$AIKIT/bin/ai-kit-which.sh" "asdf qwerty zxcv hjkl" 2>&1)"
WHICH_NONE_EXIT=$?
set -e
assert "which: gibberish reports no match" 'echo "$OUT_WHICH_NONE" | grep -q "No skill description matched"'
assert "which: gibberish exits 1" '[ "$WHICH_NONE_EXIT" -eq 1 ]'


print_summary_and_exit
