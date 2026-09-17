#!/usr/bin/env bash
# Claude Code PreToolUse hook: hand multi-file implementation to the builder.
#
# The `builder` subagent exists so a multi-file change is built test-first in
# its own context and only the report comes back. In practice the main thread
# edits six files inline and never reaches for it — the same failure the
# search-delegation hook closes for grep: a rule is prose an agent skips under
# pressure. This hook puts the instruction at the moment of reaching, and the
# reach is the third distinct file.
#
# Fires ONCE per session, on the 3rd DISTINCT file_path seen in an Edit /
# Write / MultiEdit. Everything else is silent:
#
#   - the 1st and 2nd file — a one- or two-file change is fine inline
#   - the 4th and later — one nudge is signal, one per edit is noise
#   - repeat edits to a file already counted — iterating on one file is not
#     a multi-file change
#   - any other tool, an unparseable payload, a missing session_id or
#     file_path, an unwritable temp dir
#
# State is one file per session under ${TMPDIR:-/tmp}, listing the distinct
# paths seen; the count being exactly 3 is what "fired" means, so there is
# no second marker to keep in step.
#
# ponytail: session-scoped count with no per-turn reset — three unrelated
# one-file fixes in one long session look like a multi-file change. And there
# is no signal for whether the caller is itself a subagent, so the message
# tells the agent to ignore it there. Upgrade path if either bites: key the
# state on the turn (UserPromptSubmit hook truncates it) and/or gate on a
# parent-agent field once the payload carries one.
#
# Advisory only: emits additionalContext, never blocks, always exits 0.
#
# Wire it up with bin/apply-build-delegation-hook.sh, or by hand:
#
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Edit|Write|MultiEdit",
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/build-delegation-check.sh"
#         }]
#       }]
#     }
#   }

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
keys = sys.argv[1].lstrip(".").split(".")
cur = d
for k in keys:
    if not isinstance(cur, dict):
        sys.exit(0)
    cur = cur.get(k)
    if cur is None:
        sys.exit(0)
print(cur if isinstance(cur, str) else "")' "$1" <<<"$payload" 2>/dev/null
  fi
}

case "$(read_field '.tool_name')" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

session="$(read_field '.session_id')"
path="$(read_field '.tool_input.file_path')"
{ [ -z "$session" ] || [ -z "$path" ]; } && exit 0

state="${TMPDIR:-/tmp}/ai-kit-build-delegation-${session//[^A-Za-z0-9_-]/_}"
grep -qxF -- "$path" "$state" 2>/dev/null && exit 0
{ printf '%s\n' "$path" >>"$state"; } 2>/dev/null || exit 0
[ "$(wc -l <"$state" | tr -d ' ')" -eq 3 ] || exit 0

msg="build-delegation: three or more files edited inline this session — this is a multi-file change. Delegate the remaining implementation to the \`builder\` subagent (test-first, verifies before reporting) so the main context stays free for review. Ignore if you are already inside a subagent or the change is nearly finished."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$msg" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
else
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
