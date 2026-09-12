#!/usr/bin/env bash
# Install the ai-kit phase-check hook into a target project.
#
#   1. Copy bin/hooks/phase-check.sh into TARGET/.claude/hooks/ so the project
#      references it by a portable ${CLAUDE_PROJECT_DIR}-relative path (no
#      absolute ai-kit path baked into a committed settings.json).
#   2. Merge a UserPromptSubmit entry into TARGET/.claude/settings.json —
#      non-destructive (keeps every other key and hook) and idempotent.
#
# Usage: apply-phase-check-hook.sh /path/to/project
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/settings-hooks.sh
source "$SCRIPT_BIN/lib/settings-hooks.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/project" >&2
  exit 1
fi
TARGET="$(cd "$1" && pwd)"

HOOK_SRC="$AIKIT/bin/hooks/phase-check.sh"
[ -f "$HOOK_SRC" ] || { echo "Hook source missing: $HOOK_SRC" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to merge settings.json" >&2
  exit 1
}

mkdir -p "$TARGET/.claude/hooks"
cp "$HOOK_SRC" "$TARGET/.claude/hooks/phase-check.sh"
chmod +x "$TARGET/.claude/hooks/phase-check.sh"

wire_hook "$TARGET/.claude/settings.json" "UserPromptSubmit" "" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh'

echo "phase-check hook installed in $TARGET"
