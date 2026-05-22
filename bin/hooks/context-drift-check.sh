#!/usr/bin/env bash
# Claude Code PostToolUse hook: nudge when edited code drifts from the docs.
#
# Fires after Edit/Write/MultiEdit. If the edited file's repo-relative path is
# referenced in CONTEXT.md, CONTEXT-MAP.md, or docs/adr/*.md, it emits an
# additionalContext reminder to keep the doc in sync. Stack-agnostic: drift is
# defined as "you changed code the docs name" — no framework-specific paths.
#
# Silent no-op when no such docs exist, when the payload is empty, or when the
# edited file is not referenced anywhere. Always exits 0 — a hook must never
# break a session.
#
# Wire it up with bin/apply-context-drift-hook.sh, or by hand in
# .claude/settings.json:
#
#   {
#     "hooks": {
#       "PostToolUse": [{
#         "matcher": "Edit|Write|MultiEdit",
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/context-drift-check.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

# Project root: Claude Code exports CLAUDE_PROJECT_DIR; fall back to cwd.
root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Edited file — Edit, Write and MultiEdit all carry tool_input.file_path.
file_path="$(
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    print(json.loads(sys.stdin.read()).get("tool_input", {}).get("file_path", ""))
except Exception:
    pass' <<<"$payload" 2>/dev/null
  fi
)"
[ -z "$file_path" ] && exit 0

# Repo-relative path: strip the root prefix and any leading "./".
rel="${file_path#"$root"/}"
rel="${rel#./}"
[ -z "$rel" ] && exit 0

# Collect drift-tracked docs that actually exist.
docs=()
for d in "$root/CONTEXT.md" "$root/CONTEXT-MAP.md"; do
  [ -f "$d" ] && docs+=("$d")
done
if [ -d "$root/docs/adr" ]; then
  for d in "$root/docs/adr"/*.md; do
    [ -f "$d" ] && docs+=("$d")
  done
fi
[ "${#docs[@]}" -eq 0 ] && exit 0

# Which docs name this file? Fixed-string match on the repo-relative path.
hits=()
for d in "${docs[@]}"; do
  if grep -qF "$rel" "$d" 2>/dev/null; then
    hits+=("${d#"$root"/}")
  fi
done
[ "${#hits[@]}" -eq 0 ] && exit 0

joined="$(IFS=', '; echo "${hits[*]}")"
msg="context-drift: \`${rel}\` is referenced in ${joined}. If this edit changed documented behaviour, update the doc(s) or run /aikit-grill-with-docs."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$msg" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
else
  # Hand-rolled JSON fallback — escape backslashes and double quotes.
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
