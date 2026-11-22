# shellcheck shell=bash
# One reader for a project's .ai-kit-setup marker (#184). A marker that fails
# to parse is an error on stderr and a non-zero exit, never a silent default.
#
# marker_get <marker> <dotted.key> [default]
#   Prints the value at the key; booleans as true/false; a missing key prints
#   the default (empty when none given).

marker_get() {
  python3 - "$@" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
default = sys.argv[3] if len(sys.argv) > 3 else ""
try:
    with open(path) as f:
        value = json.load(f)
except (OSError, ValueError) as e:
    print(f"{path}: {e}", file=sys.stderr)
    sys.exit(1)
for part in key.split("."):
    value = value.get(part) if isinstance(value, dict) else None
if value is None:
    print(default)
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

# marker_hook_on <project> <hook-name> <default>
#   Succeeds when the project's marker has branches.<hook_name>_hook = wired,
#   or <default> = wired and the key is absent. No marker or an unreadable
#   one: fails.
marker_hook_on() {
  [ -f "$1/.ai-kit-setup" ] &&
    [ "$(marker_get "$1/.ai-kit-setup" "branches.${2//-/_}_hook" "$3" 2>/dev/null)" = wired ]
}

# marker_project_skills_merged <marker>
#   Prints true when the project carries its own skill dirs (ADR-0012).
#   skip_skill_merge=true is the v1.79 retrofit of project_skills_merged=false;
#   a marker without either field derives it from setup_mode, where only
#   solo-global (legacy global-only) meant "skip the project skill dirs".
marker_project_skills_merged() {
  local raw mode
  raw="$(marker_get "$1" branches.project_skills_merged)" || return 1
  if [ -z "$raw" ] && [ "$(marker_get "$1" branches.skip_skill_merge)" = true ]; then
    raw=false
  fi
  if [ -n "$raw" ]; then
    echo "$raw"
    return 0
  fi
  mode="$(marker_get "$1" branches.setup_mode)"
  [ -n "$mode" ] || mode="$(marker_get "$1" branches.agent_stack)"
  case "$mode" in
    solo-global | global-only) echo false ;;
    *) echo true ;;
  esac
}
