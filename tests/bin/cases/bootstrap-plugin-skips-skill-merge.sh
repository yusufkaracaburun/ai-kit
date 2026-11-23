#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #172: when the Claude Code plugin serves ai-kit skills, project skill links
# only duplicate them and point at a home path outside the repo.

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

boot() { HOME="$1" bash "$AIKIT/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "${@:2}" >/dev/null; }
empty() { [ -z "$(ls -A "$1" 2>/dev/null)" ]; }

echo "=== bootstrap: plugin serves skills, no project skill merge ==="
# section: bootstrap-plugin-skips-skill-merge
mkdir -p "$H/with/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"
boot "$H/with" "$H/with/proj"
assert "plugin: no ai-kit entries in .claude/skills" 'empty "$H/with/proj/.claude/skills"'
assert "plugin: no ai-kit entries in .agents/skills" 'empty "$H/with/proj/.agents/skills"'
boot "$H/with" "$H/with/proj-noskills" --no-skills
assert "plugin + --no-skills: .claude/skills empty" 'empty "$H/with/proj-noskills/.claude/skills"'
assert "plugin + --no-skills: .agents/skills empty" 'empty "$H/with/proj-noskills/.agents/skills"'
boot "$H/with" "$H/with/proj-linkall" --link-all
assert "plugin + --link-all: explicit request still links" '[ -L "$H/with/proj-linkall/.claude/skills" ]'

mkdir -p "$H/without"
boot "$H/without" "$H/without/proj"
assert "no plugin: .claude/skills still merged" '[ -L "$H/without/proj/.claude/skills/setup" ]'
assert "no plugin: .agents/skills still merged" '[ -L "$H/without/proj/.agents/skills/setup" ]'

mkdir -p "$H/symlink/.config/ai-kit"
echo "$AIKIT" > "$H/symlink/.config/ai-kit/root"
boot "$H/symlink" "$H/symlink/proj"
assert "symlink-install only: .claude/skills still merged" '[ -L "$H/symlink/proj/.claude/skills/setup" ]'

print_summary_and_exit
