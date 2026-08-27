#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# install-global.sh symlinks ai-kit's skills/agents/commands from this repo
# into ~/.claude, ~/.agents, and ~/.cursor. Every case here runs with HOME
# redirected into a temp dir, so the developer's real machine is never
# touched. AI_KIT_ROOT is left unset — the script resolves its own root from
# its own path (bin/..), which is this real repo, so it reads real skills
# but writes only into the sandboxed HOME.
#
# NOT COVERED: the install-global.sh invocation from within a *plugin*
# install (where resolve_primitives_root would pick the non-workflow
# branch) — this dev clone always has workflow/skills/, so that branch
# never runs here.

install_global() {
  # install_global <sandbox_home>
  local home="$1"
  HOME="$home" bash "$AIKIT/bin/install-global.sh"
}

echo "=== fresh install ==="
H=$(mktemp -d)
OUT=$(install_global "$H")
assert "links a known skill into ~/.claude/skills" '[ -L "$H/.claude/skills/audit-architecture" ]'
assert "skill symlink resolves into the aikit source tree" \
  'readlink "$H/.claude/skills/audit-architecture" | grep -q "workflow/skills/audit-architecture"'
assert "links a known agent into ~/.claude/agents" '[ -L "$H/.claude/agents/explore" ]'
assert "links a known command into ~/.claude/commands" '[ -L "$H/.claude/commands/doctor.md" ]'
assert "also links skills into ~/.agents/skills (legacy path)" '[ -L "$H/.agents/skills/audit-architecture" ]'
assert "also links skills into ~/.cursor/skills" '[ -L "$H/.cursor/skills/audit-architecture" ]'
assert "also links commands into ~/.cursor/commands" '[ -L "$H/.cursor/commands/doctor.md" ]'
assert "writes the ai-kit root config" 'grep -qx "$AIKIT" "$H/.config/ai-kit/root"'
rm -rf "$H"

echo "=== existing non-aikit entry is skipped, not clobbered ==="
H=$(mktemp -d)
mkdir -p "$H/.claude/skills/audit-architecture"
echo "mine" > "$H/.claude/skills/audit-architecture/marker.txt"
OUT=$(install_global "$H")
assert "reports the existing entry as skipped" \
  'grep -q "Skipped audit-architecture (existing non-aikit entry" <<<"$OUT"'
assert "existing dir stays a real dir, not replaced by a symlink" \
  '[ ! -L "$H/.claude/skills/audit-architecture" ]'
assert "existing dir's contents are untouched" '[ -f "$H/.claude/skills/audit-architecture/marker.txt" ]'
rm -rf "$H"

echo "=== idempotent re-run ==="
H=$(mktemp -d)
install_global "$H" >/dev/null
OUT2=$(install_global "$H")
# Positive assertion first: the previous version only checked that "Skipped"
# was absent (true of empty output) and that a symlink the FIRST run created
# still existed. Both passed with the installer replaced by `true`, so the
# re-link branch was not actually covered.
assert "re-run reports it linked the skill again" \
  'grep -q "Linked audit-architecture" <<<"$OUT2"'
assert "re-run does not warn about a foreign symlink" \
  '! grep -q "Skipped audit-architecture" <<<"$OUT2"'
assert "symlink still resolves to the repo after the second run" \
  '[ -L "$H/.claude/skills/audit-architecture" ] && [ -e "$H/.claude/skills/audit-architecture" ]'
rm -rf "$H"

echo "=== prefer-plugin marker: skips ~/.claude, keeps ~/.cursor ==="
H=$(mktemp -d)
mkdir -p "$H/.config/ai-kit"
: > "$H/.config/ai-kit/prefer-plugin"
OUT=$(install_global "$H")
assert "skills skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/skills/audit-architecture" ]'
assert "agents skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/agents/explore" ]'
assert "commands skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/commands/doctor.md" ]'
assert "output explains the skip" 'grep -q "skipped (prefer-plugin marker)" <<<"$OUT"'
assert "cursor has no plugin namespace, so its skills still link" '[ -L "$H/.cursor/skills/audit-architecture" ]'
assert "cursor commands still link" '[ -L "$H/.cursor/commands/doctor.md" ]'
rm -rf "$H"

echo "=== dead ai-kit symlinks are reclaimed, foreign dead links are not ==="
H=$(mktemp -d)
GONE="$H/moved-away/ai-kit/workflow"
mkdir -p "$H/.agents/skills" "$H/.cursor/commands"
# A link to a skill that still exists in the source tree, and one to a name
# that no longer does (a rename orphan the entry loop never visits).
ln -s "$GONE/skills/audit-architecture/" "$H/.agents/skills/audit-architecture"
ln -s "$GONE/skills/aikit-tdd/" "$H/.agents/skills/aikit-tdd"
ln -s "$GONE/commands/doctor.md" "$H/.cursor/commands/doctor.md"
# Someone else's dead links — not ours to delete. `qa` collides with a name
# in the source tree, so it also exercises the entry loop's non-clobber arm;
# `mine` does not, so only the sweep ever sees it.
ln -s "/nonexistent/other-tool/skills/qa/" "$H/.agents/skills/qa"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "relinks a dead ai-kit skill link into the repo" \
  '[ -e "$H/.agents/skills/audit-architecture" ] && readlink "$H/.agents/skills/audit-architecture" | grep -q "workflow/skills/audit-architecture"'
assert "removes a dead ai-kit link whose skill no longer exists" \
  '[ ! -L "$H/.agents/skills/aikit-tdd" ]'
assert "reports the orphan removal" 'grep -q "Removed dead link aikit-tdd" <<<"$OUT"'
assert "relinks a dead ai-kit command link" \
  '[ -e "$H/.cursor/commands/doctor.md" ]'
assert "names the old target when it removes a link" \
  'grep -q "Removed dead link aikit-tdd (was -> $GONE/skills/aikit-tdd/)" <<<"$OUT"'
assert "leaves a foreign dead link alone" \
  '[ -L "$H/.agents/skills/mine" ] && [ ! -e "$H/.agents/skills/mine" ]'
assert "does not report the foreign link as removed" \
  '! grep -q "Removed dead link mine" <<<"$OUT"'
assert "a foreign dead link on a colliding name stays dead" \
  '[ -L "$H/.agents/skills/qa" ] && [ ! -e "$H/.agents/skills/qa" ]'
assert "and is reported as an existing non-aikit entry" \
  'grep -q "Skipped qa (existing non-aikit entry" <<<"$OUT"'
rm -rf "$H"

echo "=== links from a previous root with no /ai-kit/ segment are reclaimed ==="
# A plugin install pins its version into the path
# (~/.claude/plugins/cache/<owner>/ai/<version>), so after an upgrade its
# links are dead and match no /ai-kit/ pattern. ~/.config/ai-kit/root still
# holds the root they were made from.
H=$(mktemp -d)
OLD_PLUGIN="$H/.claude/plugins/cache/owner/ai/1.62.0"
mkdir -p "$H/.config/ai-kit" "$H/.agents/skills" "$H/.cursor/commands"
printf '%s\n' "$OLD_PLUGIN" > "$H/.config/ai-kit/root"
ln -s "$OLD_PLUGIN/skills/audit-architecture/" "$H/.agents/skills/audit-architecture"
ln -s "$OLD_PLUGIN/skills/aikit-tdd/" "$H/.agents/skills/aikit-tdd"
ln -s "$OLD_PLUGIN/commands/doctor.md" "$H/.cursor/commands/doctor.md"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "relinks a live skill name from the previous root" \
  '[ -e "$H/.agents/skills/audit-architecture" ]'
assert "removes an orphan from the previous root" '[ ! -L "$H/.agents/skills/aikit-tdd" ]'
assert "removes an orphan command from the previous root" \
  '[ -e "$H/.cursor/commands/doctor.md" ]'
assert "still leaves a foreign dead link alone" '[ -L "$H/.agents/skills/mine" ]'
rm -rf "$H"

echo "=== no previous root: the empty value must not match every path ==="
H=$(mktemp -d)
mkdir -p "$H/.agents/skills"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "foreign dead link survives when ~/.config/ai-kit/root is absent" \
  '[ -L "$H/.agents/skills/mine" ]'
rm -rf "$H"

print_summary_and_exit
