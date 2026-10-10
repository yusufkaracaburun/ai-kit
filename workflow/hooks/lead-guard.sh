#!/usr/bin/env bash
# Claude Code PreToolUse hook: a lead session dispatches, it never executes.
# A lead (claim role=lead, bin/ai-kit-claim.sh) still did design edits, browser
# runs and store writes inline with the prose rule loaded, so this is a gate:
# work tool calls from the lead's main thread (no agent_id) are denied, naming
# the subagent to hand them to. Memo and temp-dir writes pass.
# Override: `ai-kit-claim.sh set role=build`.
# Always exits 0. Fails open (silent) without jq or python3, on purpose.
# Wired for the plugin in workflow/hooks/hooks.json.

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

[ -n "$(read_field '.agent_id')" ] && exit 0

session="$(read_field '.session_id')"
[ -z "$session" ] && exit 0
claim="${HOME}/.config/ai-kit/claims/${session//[^A-Za-z0-9_-]/_}.md"
[ -f "$claim" ] || exit 0
role="$(awk '
  NR==1 && /^---$/ { fm=1; next }
  fm && /^---$/ { exit }
  fm && index($0, "role: ") == 1 { print substr($0, 7); exit }
' "$claim" 2>/dev/null)"
[ "$role" = "lead" ] || exit 0

tool="$(read_field '.tool_name')"

is_work_command() {
  local cmd="$1" re=""
  # A tool counts only at the head of a pipeline segment, after env assignments
  # and a path prefix, so `grep pest` or `cat Pest.php` stay reads.
  local head='(^|[;&|(`])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:];&|]*/)?'
  local end='($|[[:space:];&|)`])'
  re+="|git (commit|push|merge|rebase|cherry-pick|reset|restore|clean|add)|git checkout (\.|--)"
  re+="|git stash([[:space:]]+(push|pop|drop|apply|clear|save|branch|store|create))?[[:space:]]*($|[;&|)])"
  re+="|git branch (-[dD]|--delete)|git worktree remove"
  re+="|rm|sed -i|tee|mv|cp|chmod"
  re+="|npm (test|run|install|ci)|npx|pnpm|yarn|jest|vitest|playwright"
  re+="|pest|paratest|phpunit|php artisan|composer (install|update|require)|make"
  re+="|flutter (test|build|run|pub)|dart|patrol|maestro|xcodebuild|xcrun simctl boot|gradlew?|eas"
  re+="|gh (pr|issue|release|repo) (create|edit|merge|close|delete)|gh pr (comment|review)|gh issue comment"
  re+="|gh api [^;&|]*(-X|--method)|open -a|kill|pkill|killall"
  re="${head}(${re#|})${end}"

  # App Store Connect: reads pass, everything else writes
  local asc="${head}asc " asc_read="${head}asc .* (get|list|read)"
  # redirect to a file; /dev/null, fd merges and temp-dir targets are stripped first
  local redirect='(>>|[[:space:]]>)' stripped="$cmd"
  [ -n "${TMPDIR:-}" ] && stripped="${stripped//"$TMPDIR"//tmp/}"
  stripped="$(sed -E 's#\$\{?TMPDIR\}?#/tmp/#g; s#[0-9&]*>>? */dev/null##g; s#[0-9]*>&[0-9]##g; s#>>? *(/private)?/tmp/[^[:space:]]*##g' <<<"$stripped")"

  # quoted text is an argument, not a command: `grep -E 'pest|gradle'`
  local unquoted
  unquoted="$(sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" <<<"$cmd")"

  shopt -s nocasematch
  [[ $unquoted =~ $re ]] && return 0
  [[ $cmd =~ $asc ]] && ! [[ $cmd =~ $asc_read ]] && return 0
  [[ $stripped =~ $redirect ]] && return 0
  return 1
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(read_field '.tool_input.file_path')"
    [ -z "$path" ] && path="$(read_field '.tool_input.notebook_path')"
    case "$path" in
      */.agents/memory/*|*/.planning/*|"$HOME"/.claude/*|/tmp/*|/private/tmp/*|"${TMPDIR:-/tmp/}"*) exit 0 ;;
    esac
    ;;
  Bash) is_work_command "$(read_field '.tool_input.command')" || exit 0 ;;
  mcp__pencil__execute) ;;
  mcp__claude-in-chrome__computer|mcp__claude-in-chrome__form_input|mcp__claude-in-chrome__navigate|\
  mcp__claude-in-chrome__javascript_tool|mcp__claude-in-chrome__shortcuts_execute|\
  mcp__claude-in-chrome__file_upload|mcp__claude-in-chrome__upload_image|\
  mcp__claude-in-chrome__tabs_create_mcp|mcp__claude-in-chrome__tabs_close_mcp|\
  mcp__claude-in-chrome__resize_window|mcp__claude-in-chrome__browser_batch) ;;
  *) exit 0 ;;
esac

msg="lead-guard: this session is lead (claim role=lead). The lead dispatches, it never executes. $tool is work: hand it to a subagent (ai:builder for code, ai:designer for .pen/UI, general-purpose for CLI, browser and store consoles; the subagent default model applies; pass model only when another one fits the task). The lead keeps reads, status commands, one lookup, peer messages, claims and memos. Not the lead for this repo? \`ai-kit-claim.sh set role=build\`."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$msg" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
else
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
fi
exit 0
