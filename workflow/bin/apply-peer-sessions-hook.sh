#!/usr/bin/env bash
# Install the peer-sessions hook into a target project.
#
#   1. Copy bin/hooks/peer-sessions-check.sh AND bin/ai-kit-claim.sh (the
#      helper it calls) into TARGET/.claude/hooks/ so the project references
#      them by a portable ${CLAUDE_PROJECT_DIR}-relative path (no absolute
#      ai-kit path baked into a committed settings.json).
#   2. Merge a SessionStart entry into TARGET/.claude/settings.json —
#      non-destructive (keeps every other key and hook) and idempotent.
#
# Usage: apply-peer-sessions-hook.sh /path/to/project
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

HOOK_SRC="$AIKIT/bin/hooks/peer-sessions-check.sh"
CLAIM_SRC="$AIKIT/bin/ai-kit-claim.sh"
[ -f "$HOOK_SRC" ] || { echo "Hook source missing: $HOOK_SRC" >&2; exit 1; }
[ -f "$CLAIM_SRC" ] || { echo "Helper source missing: $CLAIM_SRC" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to merge settings.json" >&2
  exit 1
}

mkdir -p "$TARGET/.claude/hooks"
cp "$HOOK_SRC" "$TARGET/.claude/hooks/peer-sessions-check.sh"
cp "$CLAIM_SRC" "$TARGET/.claude/hooks/ai-kit-claim.sh"
chmod +x "$TARGET/.claude/hooks/peer-sessions-check.sh" "$TARGET/.claude/hooks/ai-kit-claim.sh"

wire_hook "$TARGET/.claude/settings.json" "SessionStart" "" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/peer-sessions-check.sh'

echo "peer-sessions hook installed in $TARGET"
