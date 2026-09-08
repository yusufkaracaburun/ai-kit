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

SETTINGS="$TARGET/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
cmd = "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh"

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
ups = hooks.get("UserPromptSubmit")
if not isinstance(ups, list):
    ups = hooks["UserPromptSubmit"] = []

already = any(
    h.get("command") == cmd
    for b in ups if isinstance(b, dict)
    for h in b.get("hooks", []) if isinstance(h, dict)
)

if already:
    print("phase-check hook already wired; settings.json unchanged")
    sys.exit(0)

ups.append({"hooks": [{"type": "command", "command": cmd}]})

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("wired phase-check hook into", path)
PY

echo "phase-check hook installed in $TARGET"
