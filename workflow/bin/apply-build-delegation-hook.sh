#!/usr/bin/env bash
# Install the build-delegation hook into a target project: copy
# bin/hooks/build-delegation-check.sh into TARGET/.claude/hooks/ and merge a
# PreToolUse(Edit|Write|MultiEdit) entry into TARGET/.claude/settings.json
# — non-destructive and idempotent (bin/lib/settings-hooks.sh).
#
# Usage: apply-build-delegation-hook.sh /path/to/project
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

install_project_hook "$TARGET" "$AIKIT/bin/hooks/build-delegation-check.sh" "PreToolUse" "Edit|Write|MultiEdit" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/build-delegation-check.sh'

echo "build-delegation hook installed in $TARGET"
