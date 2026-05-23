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

SETTINGS="$TARGET/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
cmd = "${CLAUDE_PROJECT_DIR}/.claude/hooks/context-drift-check.sh"
matcher = "Edit|Write|MultiEdit"

try:
    with open(path) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = data["hooks"] = {}
post = hooks.get("PostToolUse")
if not isinstance(post, list):
    post = hooks["PostToolUse"] = []

# Idempotent: skip if this command is already wired anywhere in PostToolUse.
already = any(
    isinstance(block, dict)
    and any(
        isinstance(h, dict) and h.get("command") == cmd
        for h in block.get("hooks", [])
    )
    for block in post
)

if already:
    print("context-drift hook already wired; settings.json unchanged")
else:
    post.append({
        "matcher": matcher,
        "hooks": [{"type": "command", "command": cmd}],
    })
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("wired context-drift hook into", path)
PY

echo "context-drift hook installed in $TARGET"
