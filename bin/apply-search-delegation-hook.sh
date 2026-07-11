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

SETTINGS="$TARGET/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
cmd = "${CLAUDE_PROJECT_DIR}/.claude/hooks/search-delegation-check.sh"
matcher = "Bash|Grep|Glob"
LEGACY_MARKER = "graphify-out/graph.json"

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
pre = hooks.get("PreToolUse")
if not isinstance(pre, list):
    pre = hooks["PreToolUse"] = []


def commands(block):
    if not isinstance(block, dict):
        return []
    return [
        h.get("command", "")
        for h in block.get("hooks", [])
        if isinstance(h, dict)
    ]


already = any(cmd in commands(b) for b in pre)
legacy = [b for b in pre if any(LEGACY_MARKER in c for c in commands(b))]

if legacy:
    for b in legacy:
        pre.remove(b)

if already and not legacy:
    print("search-delegation hook already wired; settings.json unchanged")
    sys.exit(0)

if not already:
    pre.append({
        "matcher": matcher,
        "hooks": [{"type": "command", "command": cmd}],
    })

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

if legacy:
    print(f"replaced {len(legacy)} legacy graphify-only nudge(s) with the search-delegation hook in {path}")
else:
    print("wired search-delegation hook into", path)
PY

echo "search-delegation hook installed in $TARGET"
