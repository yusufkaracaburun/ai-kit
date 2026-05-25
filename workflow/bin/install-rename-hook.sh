#!/usr/bin/env bash
# Install the rename-detector SessionStart hook into ~/.claude/.
#
#   1. Copy bin/hooks/rename-detector.sh into ~/.claude/hooks/ so the user-global
#      settings.json references it by an absolute $HOME-relative path
#      (no ai-kit checkout path baked into ~/.claude/settings.json).
#   2. Merge a SessionStart entry into ~/.claude/settings.json — non-destructive
#      (keeps every other key and existing hook) and idempotent (a second run
#      changes nothing).
#   3. Touch ~/.claude/known-projects.json with an empty registry if missing.
#
# Usage: install-rename-hook.sh [--uninstall]
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

UNINSTALL=0
if [ "${1:-}" = "--uninstall" ]; then
  UNINSTALL=1
fi

CLAUDE_DIR="$HOME/.claude"
HOOK_DST_DIR="$CLAUDE_DIR/hooks"
HOOK_DST="$HOOK_DST_DIR/rename-detector.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
REGISTRY="$CLAUDE_DIR/known-projects.json"

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to merge settings.json" >&2
  exit 1
}

mkdir -p "$HOOK_DST_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if [ "$UNINSTALL" -eq 1 ]; then
  rm -f "$HOOK_DST"
  python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
cmd_needle = "rename-detector.sh"

try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError as e:
    print(f"refusing to overwrite malformed settings.json: {path} ({e})", file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict):
    print(f"refusing: settings.json is not a JSON object: {path}", file=sys.stderr)
    sys.exit(1)

hooks = data.get("hooks") if isinstance(data.get("hooks"), dict) else None
removed = 0
if hooks:
    sess = hooks.get("SessionStart")
    if isinstance(sess, list):
        new_sess = []
        for block in sess:
            if not isinstance(block, dict):
                new_sess.append(block); continue
            inner = block.get("hooks", [])
            kept = [
                h for h in inner
                if not (isinstance(h, dict) and cmd_needle in str(h.get("command", "")))
            ]
            removed += len(inner) - len(kept)
            if kept:
                block["hooks"] = kept
                new_sess.append(block)
            # block with no hooks left is dropped silently
        if new_sess:
            hooks["SessionStart"] = new_sess
        else:
            hooks.pop("SessionStart", None)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"uninstalled rename-detector ({removed} entries removed)")
PY
  echo "rename-detector hook removed from $CLAUDE_DIR"
  exit 0
fi

HOOK_SRC="$AIKIT/bin/hooks/rename-detector.sh"
[ -f "$HOOK_SRC" ] || { echo "Hook source missing: $HOOK_SRC" >&2; exit 1; }

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"

# Seed an empty registry so the hook's first read never trips on missing file.
[ -f "$REGISTRY" ] || echo '{"projects":[]}' > "$REGISTRY"

python3 - "$SETTINGS" "$HOOK_DST" <<'PY'
import json, sys

path, hook_path = sys.argv[1], sys.argv[2]
cmd = f'bash "{hook_path}"'

try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError as e:
    print(f"refusing to overwrite malformed settings.json: {path} ({e})", file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict):
    print(f"refusing: settings.json is not a JSON object: {path}", file=sys.stderr)
    sys.exit(1)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = data["hooks"] = {}
sess = hooks.get("SessionStart")
if not isinstance(sess, list):
    sess = hooks["SessionStart"] = []

# Idempotent: skip if any block in SessionStart already references this hook.
already = any(
    isinstance(block, dict)
    and any(
        isinstance(h, dict) and "rename-detector.sh" in str(h.get("command", ""))
        for h in block.get("hooks", [])
    )
    for block in sess
)

if already:
    print("rename-detector already wired; settings.json unchanged")
else:
    sess.append({
        "hooks": [{"type": "command", "command": cmd}],
    })
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("wired rename-detector into", path)
PY

echo "rename-detector hook installed in $CLAUDE_DIR"
echo "registry: $REGISTRY"
