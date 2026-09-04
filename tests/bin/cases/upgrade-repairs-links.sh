#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #114 (naschool comment): "/ai:upgrade re-stamps the marker but never
# touches the links" — the one command whose job is moving a project to the
# new ai-kit version moved the version STRING and left the version PATHS.
# A project bootstrapped before the plugin-current indirection (#114 slice A)
# has links pinned straight into a version-numbered plugin cache dir; once
# that version is GC'd they brick, and nothing about running /ai:upgrade
# fixed that. ai-kit-upgrade.sh must now also repair project skill/agent/
# command links against the current version — link-all mode gets its single
# symlink repointed, merge mode gets each entry relinked, custom entries and
# --no-skills/--no-agents/--no-commands projects are left untouched.

# shellcheck source=../../../bin/lib/ai-kit-root.sh
source "$AIKIT/bin/lib/ai-kit-root.sh"

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

make_fake_version() {
  local version="$1" marker="$2"
  local root="$H/plugins/cache/mkt/ai/$version"
  mkdir -p "$root/bin" "$root/workflow/skills/demo-skill" "$root/workflow/agents" "$root/workflow/commands"
  cp -R "$AIKIT/bin/." "$root/bin/"
  ln -sfn "$AIKIT/context" "$root/context"
  printf '%s\n' "$version" > "$root/VERSION"
  printf '# demo-skill (%s)\n' "$marker" > "$root/workflow/skills/demo-skill/SKILL.md"
  echo "$root"
}

write_marker() {
  local target="$1" version="$2"
  printf '{\n  "ai_kit_version": "%s",\n  "completed_at": "2026-01-01T00:00:00Z"\n}\n' "$version" \
    > "$target/.ai-kit-setup"
}

V1="$(make_fake_version 1.0.0 v1)"
P="$H/proj-merge"
HOME="$H" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$P" >/dev/null
write_marker "$P" "1.0.0"

echo "=== a legacy link, pinned directly (pre-indirection), survives a cache GC after upgrade ==="
# Simulate a project bootstrapped before the plugin-current fix: repoint the
# entry straight at V1 instead of through plugin-current.
ln -sfn "$V1/workflow/skills/demo-skill" "$P/.claude/skills/demo-skill"
# A genuine custom project-local skill, never touched by ai-kit.
mkdir -p "$P/.claude/skills/my-custom-skill"
echo "custom" > "$P/.claude/skills/my-custom-skill/SKILL.md"

V2="$(make_fake_version 1.0.1 v2)"
rm -rf "$V1"

OUT="$(HOME="$H" bash "$V2/bin/ai-kit-upgrade.sh" "$P" 2>&1)"
assert "marker version bumped" 'grep -q "Upgraded marker 1.0.0 -> 1.0.1" <<<"$OUT"'
assert "the legacy-pinned link now resolves again" '[ -e "$P/.claude/skills/demo-skill/SKILL.md" ]'
assert "it resolves to the NEW version content" 'grep -q "v2" "$P/.claude/skills/demo-skill/SKILL.md"'
assert "custom project-local skill is untouched" 'grep -q "custom" "$P/.claude/skills/my-custom-skill/SKILL.md"'
assert "custom skill is not a symlink" '[ ! -L "$P/.claude/skills/my-custom-skill" ]'

echo "=== --link-all mode: whole-dir symlink repointed, not silently converted to merge ==="
V3="$(make_fake_version 2.0.0 v3)"
PL="$H/proj-linkall"
HOME="$H" bash "$V3/bin/bootstrap-project.sh" --minimal --link-all --no-agents --no-commands --no-rules --no-gh-workflow "$PL" >/dev/null
write_marker "$PL" "2.0.0"
ln -sfn "$V3/workflow/skills" "$PL/.claude/skills"

V4="$(make_fake_version 2.0.1 v4)"
rm -rf "$V3"
HOME="$H" bash "$V4/bin/ai-kit-upgrade.sh" "$PL" >/dev/null 2>&1
assert "link-all skills dir is still a single symlink (not converted to merge)" '[ -L "$PL/.claude/skills" ]'
assert "it resolves to the NEW version content" 'grep -q "v4" "$PL/.claude/skills/demo-skill/SKILL.md"'

echo "=== --no-skills project: repair never creates a skills dir that was never there ==="
V5="$(make_fake_version 3.0.0 v5)"
PN="$H/proj-noskills"
HOME="$H" bash "$V5/bin/bootstrap-project.sh" --minimal --no-skills --no-agents --no-commands --no-rules --no-gh-workflow "$PN" >/dev/null
write_marker "$PN" "3.0.0"
HOME="$H" bash "$V5/bin/ai-kit-upgrade.sh" "$PN" >/dev/null 2>&1
assert "no .claude/skills materialized" '[ ! -e "$PN/.claude/skills" ]'

print_summary_and_exit
