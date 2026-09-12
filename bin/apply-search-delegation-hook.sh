#!/usr/bin/env bash
# Install the search-delegation hook into a target project.
#
#   1. Copy bin/hooks/search-delegation-check.sh into TARGET/.claude/hooks/ so
#      the project references it by a portable ${CLAUDE_PROJECT_DIR}-relative
#      path (no absolute ai-kit path baked into a committed settings.json).
#   2. Merge a PreToolUse(Bash|Grep|Glob) entry into TARGET/.claude/settings.json
#      — non-destructive (keeps every other key and hook) and idempotent.
#   3. Migrate: an older inline graphify-only nudge (recognisable by the
#      literal "graphify-out/graph.json" inside a PreToolUse command) is
#      REPLACED, not stacked. The new hook supersedes it — it emits the same
#      graphify message when a graph is present, and a delegate-to-sub-agent
#      message when it is not.
#
# Usage: apply-search-delegation-hook.sh /path/to/project
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

HOOK_SRC="$AIKIT/bin/hooks/search-delegation-check.sh"
[ -f "$HOOK_SRC" ] || { echo "Hook source missing: $HOOK_SRC" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to merge settings.json" >&2
  exit 1
}

mkdir -p "$TARGET/.claude/hooks"
cp "$HOOK_SRC" "$TARGET/.claude/hooks/search-delegation-check.sh"
chmod +x "$TARGET/.claude/hooks/search-delegation-check.sh"

wire_hook "$TARGET/.claude/settings.json" "PreToolUse" "Bash|Grep|Glob" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/search-delegation-check.sh' \
  "graphify-out/graph.json"

echo "search-delegation hook installed in $TARGET"
