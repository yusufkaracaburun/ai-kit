#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: remind a lead session of the reply contract.
# Always exits 0. Silent without jq or python3, on purpose.

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

session="$(read_field '.session_id')"
[ -n "$session" ] || session="${AI_KIT_SESSION_ID:-}"
[ -z "$session" ] && exit 0
claim="${HOME}/.config/ai-kit/claims/${session//[^A-Za-z0-9_-]/_}.md"
[ -f "$claim" ] || exit 0
role="$(awk '
  NR==1 && /^---$/ { fm=1; next }
  fm && /^---$/ { exit }
  fm && index($0, "role: ") == 1 { print substr($0, 7); exit }
' "$claim" 2>/dev/null)"
[ "$role" = "lead" ] || exit 0

prompt="$(read_field '.prompt')"
[ -z "$prompt" ] && exit 0
case "$prompt" in
  /*|!*|'<cross-session-message'*|'<agent-message'*|'<task-notification'*) exit 0 ;;
esac

echo 'Lead reply: open with Doing / Where / Needs-you (count) / Advice; the recommendation goes in the same turn as any question; invoke the phase skill, do not name it; after the first lookup, lookups go to an agent; briefs carry "Decisions in force".'
exit 0
