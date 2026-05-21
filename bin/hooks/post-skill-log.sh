#!/usr/bin/env bash
# Claude Code PostToolUse hook: log Skill invocations via log-skill.sh.
#
# Reads the hook JSON payload from stdin, extracts tool_input.skill, then
# calls log-skill.sh <skill> done. Silent by design — hook failures must
# never break a session.
#
# Opt-in chain:
#   1. Hook configured in .claude/settings.json
#   2. AI_KIT_USAGE=1 in the environment
#   3. Triggering tool was Skill (enforced by the matcher in settings.json,
#      double-checked here against the JSON payload)
#
# To wire it up, add to .claude/settings.json:
#
#   {
#     "hooks": {
#       "PostToolUse": [{
#         "matcher": "^Skill$",
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/bin/hooks/post-skill-log.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

# Fast path: skip JSON parsing entirely if logging is disabled.
if [ "${AI_KIT_USAGE:-0}" != "1" ]; then
  exit 0
fi

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

extract_field() {
  # $1 = field name under tool_input (e.g. "skill")
  # Prefer jq, fall back to python3. If neither is present, silently no-op —
  # the hook must never error.
  local field="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$field" '.tool_input[$f] // empty' <<<"$payload" 2>/dev/null
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | AI_KIT_HOOK_FIELD="$field" python3 -c '
import json, os, sys
try:
    data = json.loads(sys.stdin.read())
    val = data.get("tool_input", {}).get(os.environ.get("AI_KIT_HOOK_FIELD", ""), "")
    if val:
        print(val)
except Exception:
    pass
' 2>/dev/null
    return
  fi
}

tool_name="$(
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_name // empty' <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("tool_name",""))
except Exception: pass' <<<"$payload" 2>/dev/null
  fi
)"

# Defense in depth: the matcher in settings.json should already gate this,
# but a misconfig shouldn't cause us to log non-Skill events.
if [ -n "$tool_name" ] && [ "$tool_name" != "Skill" ]; then
  exit 0
fi

skill="$(extract_field skill)"
[ -z "$skill" ] && exit 0

SCRIPT_BIN="$(cd "$(dirname "$0")/.." && pwd)"
"$SCRIPT_BIN/log-skill.sh" "$skill" "done" >/dev/null 2>&1 || true
exit 0
