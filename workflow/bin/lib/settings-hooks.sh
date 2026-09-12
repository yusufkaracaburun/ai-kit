# Merge one hook command into a Claude Code settings.json, idempotently.
# Shared by the apply-*-hook.sh installers so the JSON-merge logic — and its
# malformed-file handling — lives in exactly one place.
#
# wire_hook <settings_path> <event> <matcher|""> <command> [legacy_marker]
#   Creates settings_path with '{}' if missing. Refuses (prints to stderr,
#   returns 1) rather than silently discarding a malformed settings.json —
#   every caller advertises itself as non-destructive, so this makes that
#   true instead of only true-when-JSON-parses.
#   legacy_marker, if given, removes any existing hook block in this event
#   whose command contains that substring before adding the new one (used by
#   search-delegation's migration off an older inline nudge).
wire_hook() {
  local settings="$1" event="$2" matcher="$3" cmd="$4" legacy="${5:-}"
  [ -f "$settings" ] || echo '{}' > "$settings"
  python3 - "$settings" "$event" "$matcher" "$cmd" "$legacy" <<'PY'
import json, sys

path, event, matcher, cmd, legacy = sys.argv[1:6]

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
blocks = hooks.get(event)
if not isinstance(blocks, list):
    blocks = hooks[event] = []

def commands(block):
    if not isinstance(block, dict):
        return []
    return [h.get("command", "") for h in block.get("hooks", []) if isinstance(h, dict)]

already = any(cmd in commands(b) for b in blocks)

removed = 0
if legacy:
    kept = [b for b in blocks if not any(legacy in c for c in commands(b))]
    removed = len(blocks) - len(kept)
    blocks[:] = kept

if already and not removed:
    print(f"{cmd} already wired; settings.json unchanged")
    sys.exit(0)

if not already:
    entry = {"hooks": [{"type": "command", "command": cmd}]}
    if matcher:
        entry["matcher"] = matcher
    blocks.append(entry)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

if removed:
    print(f"replaced {removed} legacy entr{'y' if removed == 1 else 'ies'} with {cmd} in {path}")
else:
    print(f"wired {cmd} into {path}")
PY
}
