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

print_summary_and_exit
