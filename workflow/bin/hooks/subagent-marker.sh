#!/usr/bin/env bash
# Claude Code SubagentStart + SubagentStop hook: keep one empty file per
# running builder or designer subagent at <git-dir>/ai-kit/subagents/<agent_id>.
#
# A project's Stop gate reads that directory to skip the test suite while a
# builder is still editing (test-suite-stop-gate recipe, requirement 5).
# SubagentStart creates the file for agent_type builder/designer (plugin
# prefix ai: accepted); SubagentStop removes it for any agent type. The git
# dir comes from the payload's cwd. Silent, always exit 0. Ships in
# workflow/hooks/hooks.json.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

read_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r "$1 // empty" <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
v = d.get(sys.argv[1].lstrip(".")) if isinstance(d, dict) else None
print(v if isinstance(v, str) else "")' "$1" <<<"$payload" 2>/dev/null
  fi
}

id="$(read_field '.agent_id')"
case "$id" in ''|*/*|.|..) exit 0 ;; esac
cwd="$(read_field '.cwd')"
[ -n "$cwd" ] || exit 0
git_dir="$(cd "$cwd" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
marks="$git_dir/ai-kit/subagents"

case "$(read_field '.hook_event_name')" in
  SubagentStart)
    case "$(read_field '.agent_type')" in
      builder|designer|ai:builder|ai:designer)
        mkdir -p "$marks" 2>/dev/null && : > "$marks/$id" 2>/dev/null ;;
    esac ;;
  SubagentStop) command rm -f "$marks/$id" 2>/dev/null ;;
esac
exit 0
