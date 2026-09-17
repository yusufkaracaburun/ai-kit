#!/usr/bin/env bash
# Install the search-delegation hook into a target project: copy
# bin/hooks/search-delegation-check.sh into TARGET/.claude/hooks/ and merge a
# PreToolUse(Bash|Grep|Glob) entry into TARGET/.claude/settings.json —
# non-destructive and idempotent (bin/lib/settings-hooks.sh).
#
# Migration: an older inline graphify-only nudge (recognisable by the literal
# "graphify-out/graph.json" inside a PreToolUse command) is REPLACED, not
# stacked. The new hook supersedes it — it emits the same graphify message
# when a graph is present, and a delegate-to-sub-agent message when it is not.
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

install_project_hook "$TARGET" "$AIKIT/bin/hooks/search-delegation-check.sh" "PreToolUse" "Bash|Grep|Glob" \
  '${CLAUDE_PROJECT_DIR}/.claude/hooks/search-delegation-check.sh' \
  "graphify-out/graph.json"

echo "search-delegation hook installed in $TARGET"
