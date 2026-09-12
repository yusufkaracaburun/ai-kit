#!/usr/bin/env bash
# Install the context-drift hook into a target project.
#
#   1. Copy bin/hooks/context-drift-check.sh into TARGET/.claude/hooks/ so the
#      project references it by a portable ${CLAUDE_PROJECT_DIR}-relative path
#      (no absolute ai-kit path baked into a committed settings.json).
#   2. Merge a PostToolUse(Edit|Write|MultiEdit) entry into
#      TARGET/.claude/settings.json — non-destructive (keeps every other key
#      and existing hook) and idempotent (a second run changes nothing).
#
# Usage: apply-context-drift-hook.sh /path/to/project
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

HOOK_SRC="$AIKIT/bin/hooks/context-drift-check.sh"
[ -f "$HOOK_SRC" ] || { echo "Hook source missing: $HOOK_SRC" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to merge settings.json" >&2
  exit 1
}

mkdir -p "$TARGET/.claude/hooks"
cp "$HOOK_SRC" "$TARGET/.claude/hooks/context-drift-check.sh"
chmod +x "$TARGET/.claude/hooks/context-drift-check.sh"

wire_hook "$TARGET/.claude/settings.json" "PostToolUse" "Edit|Write|MultiEdit" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/context-drift-check.sh'

echo "context-drift hook installed in $TARGET"
