# shellcheck shell=bash

# Hooks the plugin's hooks.json serves; an older /ai:setup copied them into
# the project's .claude/hooks/.
PLUGIN_HOOK_SCRIPTS=(search-delegation-check.sh build-delegation-check.sh phase-check.sh context-drift-check.sh)

# unwire_hook <settings> <script>: drop hooks naming .claude/hooks/<script>; exit 1 on malformed JSON.
unwire_hook() {
  [ -f "$1" ] || return 0
  python3 - "$1" "$2" <<'PY'
import json, re, sys

path, script = sys.argv[1:3]
needle = re.compile(re.escape(f".claude/hooks/{script}") + r"(?=[\s\"']|$)")

try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"refusing to overwrite malformed settings.json: {path} ({e})", file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict):
    print(f"refusing: settings.json is not a JSON object: {path}", file=sys.stderr)
    sys.exit(1)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    sys.exit(0)

removed = 0
for event in list(hooks):
    blocks = hooks[event]
    if not isinstance(blocks, list):
        continue
    for block in blocks:
        inner = block.get("hooks") if isinstance(block, dict) else None
        if isinstance(inner, list):
            block["hooks"] = [h for h in inner if not (isinstance(h, dict) and needle.search(h.get("command", "")))]
            removed += len(inner) - len(block["hooks"])
    blocks[:] = [b for b in blocks if not (isinstance(b, dict) and b.get("hooks") == [])]
    if not blocks:
        del hooks[event]

if not removed:
    sys.exit(0)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"unwired {script} from {path}")
PY
}
