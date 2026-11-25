#!/usr/bin/env bash
# Claude Code PreToolUse hook: a lead session coordinates, it never executes.
# A lead (claim role=lead, bin/ai-kit-claim.sh) still did design edits, browser
# runs and store writes inline with the prose rule loaded, so this is a gate:
# work tool calls from the lead's main thread (no agent_id) are denied, naming
# the subagent to hand them to. Memo, temp-dir and Claude Code settings-file
# (.claude/settings.json, .claude/settings.local.json) writes pass, and so do
# coordination actions (ADR-0017, 2026-11-25): CONTEXT.md, docs/decisions.md and
# docs/roadmap.md of the session's repo, Chrome screenshots, and the Bash forms
# that lib/lead-allow.pl proves and takes out before the patterns run. A Bash
# form it cannot read falls back to the patterns. Without perl nothing is taken out.
# Known limits: `gh api -f/-F` without -X writes and passes; a script written to
# a temp dir can be run from it; the patterns miss `{ git push; }`, if/then and
# do bodies, `!`, time/env/eval prefixes, a quoted "git", xargs and find -delete.
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

# Package runners pass only when the last non-flag word is a read verb
# (`npx wrangler d1 list`) and no script runner is named; a help/version flag
# passes only as the sole argument. HTTP clients pass unless they send a body
# or method; httpie body items (`a=1`, `n:=1`, `f@x`) imply POST.
segment_is_work() {
  local seg args i w url
  local lead='^[[:space:]$(`]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:]]*/)?'
  local read_verbs=' whoami list ls status info view show get describe audit outdated search why help doctor explain '
  local runners=' run run-script exec x dlx create '
  local http_write='[[:space:]](-X[[:space:]]*|--request[[:space:]=]+)(POST|PUT|PATCH|DELETE)|[[:space:]]-[A-Za-z]*[dFT]([[:space:]]|$)|[[:space:]]-d[^[:space:]]|--data|--form|--json|--upload-file|--post-|[[:space:]](POST|PUT|PATCH|DELETE)([[:space:]]|$)'
  local httpie_item='^[A-Za-z0-9_.-]+(=[^=]|=$|:=|@)'
  while IFS= read -r seg; do
    seg="${seg%%[)\`]*}"
    if [[ $seg =~ ${lead}(npx|npm|pnpm|yarn|wrangler)([[:space:]]+(.*))?$ ]]; then
      read -r -a args <<<"${BASH_REMATCH[5]}"
      [[ ${BASH_REMATCH[3]} == npx && ${#args[@]} -gt 0 && ${args[0]} != -* ]] && args=("${args[@]:1}")
      [[ ${#args[@]} -eq 1 && " --help --version -h -v " == *" ${args[0]} "* ]] && continue
      w=""
      for ((i = ${#args[@]} - 1; i >= 0; i--)); do
        [[ $runners == *" ${args[i]} "* ]] && return 0
        [[ -z $w && ${args[i]} != -* ]] && w="${args[i]}"
      done
      [[ $w == audit && " ${args[*]} " == *" --fix "* ]] && return 0
      [[ $read_verbs == *" $w "* ]] || return 0
    elif [[ $seg =~ ${lead}(curl|wget|https?|httpie)([[:space:]]|$) ]]; then
      [[ $seg =~ $http_write ]] && return 0
      [[ $seg =~ ${lead}(https?|httpie)[[:space:]]+([^[:space:]].*) ]] || continue
      read -r -a args <<<"${BASH_REMATCH[4]}"
      url=""
      for w in "${args[@]}"; do
        if [[ -n $url ]]; then
          [[ $w =~ $httpie_item ]] && return 0
        elif [[ $w != -* && $w =~ [^A-Z] ]]; then
          url="$w"
        fi
      done
    fi
  done < <(tr ';&|' '\n\n\n' <<<"$1" | grep -E 'npx|npm|yarn|wrangler|curl|wget|http')
  return 1
}

git_options_out() {
  sed -E 's/(^|[;&|(`[:space:]/])git([[:space:]]+(-[Cc][[:space:]]+[^[:space:];&|]+|--no-pager|-[pP]))+/\1git/g'
}

is_work_command() {
  # $1: the call, or the two texts of lead-allow.pl split by \x1f
  local cmd="${1%%$'\x1f'*}" re=""
  # A tool counts only at the head of a pipeline segment, after env assignments
  # and a path prefix, so `grep pest` or `cat Pest.php` stay reads.
  local head='(^|[;&|(`])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(command[[:space:]]+)?([^[:space:];&|]*/)?'
  local end='($|[[:space:];&|)`])'
  re+="|git (commit|push|merge|rebase|cherry-pick|reset|restore|clean|add)|git checkout (\.|--)"
  re+="|git stash([[:space:]]+(push|pop|drop|apply|clear|save|branch|store|create))?[[:space:]]*($|[;&|)])"
  re+="|git branch ([^;&|]*[[:space:]])?(-[a-z]*d[a-z]*|--(delete|force))|git worktree remove|git (switch|revert|am)"
  re+="|git tag[[:space:]]+(-[adfsmu]|--(annotate|delete|force|sign|message|file)|[^-[:space:];&|])[^[:space:];&|]*"
  re+="|rm|sed -i|tee|mv|cp|chmod|touch|mkdir|ln"
  re+="|jest|vitest|playwright|pytest|python3? -m pytest|cargo (build|test|run|publish|install)|go test"
  re+="|pest|paratest|phpunit|php artisan|composer (install|update|require)|make"
  re+="|flutter (test|build|run|pub)|dart|patrol|maestro|xcodebuild|xcrun simctl boot|gradlew?|eas"
  re+="|gh (pr|issue|release|repo) (create|edit|merge|close|delete)|gh pr (comment|review)|gh issue (comment|reopen|transfer|lock|unlock)"
  re+="|gh api ([^;&|]*[[:space:]])?(-X|--method)[^[:space:];&|]*|open -a|kill|pkill|killall"
  re="${head}(${re#|})${end}"

  # App Store Connect and Google Play CLIs: reads pass, everything else writes
  local asc="${head}(asc|gplay) " asc_read="${head}(asc|gplay) .* (get|list|read)"
  local apply="${head}git apply" apply_read="${head}git apply[^;&|]*--(check|stat|numstat|summary)"
  # redirect to a file; /dev/null and fd merges are stripped first. Proven
  # memo and temp targets are already gone; a call lead-allow.pl could not read
  # keeps the plain-text strip, unless a `..` could leave those dirs.
  local redirect='(>>|[[:space:]]>)' stripped
  stripped="$(sed -E 's#[0-9&]*>>? */dev/null##g; s#[0-9]*>&[0-9]##g' <<<"$cmd")"
  if [[ $1 != *$'\x1f'* && $cmd != *..* ]]; then
    [ -n "${TMPDIR:-}" ] && stripped="${stripped//"$TMPDIR"//tmp/}"
    stripped="${stripped//"$HOME"/\$HOME}"
    stripped="$(sed -E 's#\$\{?TMPDIR\}?#/tmp/#g; s#>>? *(/private)?/tmp/[^[:space:]]*##g; s#>>? *"?(\$\{?HOME\}?|~)/\.claude/[^[:space:]]*##g; s#>>? *"?([^[:space:]"]*/)?\.(agents/memory|planning)/[^[:space:]]*##g' <<<"$stripped")"
  fi

  # quoted text is an argument, not a command: `grep -E 'pest|gradle'`
  local unquoted
  unquoted="$(sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" <<<"$cmd" | git_options_out)"
  # line starts count as command heads only through this second text
  if [[ $1 == *$'\x1f'* ]]; then
    unquoted+=$'\n;'"$(git_options_out <<<"${1#*$'\x1f'}")"
  else
    unquoted="$(tr '\n' ';' <<<"$unquoted")"
  fi

  segment_is_work "$unquoted" && return 0
  # in-place perl edits; case-sensitive so `perl -Ilib` stays a read
  [[ $unquoted =~ ${head}perl[[:space:]]+(-[^[:space:]]+[[:space:]]+)*-[0-9lnpasw]*i ]] && return 0
  # forced branch moves; case-sensitive so `git branch -m` stays as it was
  [[ $unquoted =~ ${head}git\ branch\ ([^\;\&\|]*[[:space:]])?-[A-Za-z]*[MCf] ]] && return 0
  # inline interpreter code passes unless its script names a write, delete or process call
  local inline="(python[0-9.]*|node|perl)[[:space:]]+([^;&|'\"]*[[:space:]])?(-[A-Za-z]*[ce]|--eval)[[:space:]]*('[^']*'|\"[^\"]*\")"
  local write_call="write|append|unlink|remove|rmtree|rmdir|rename|os\.replace|(^|[^A-Za-z_])rm(Sync)?\(|mkdir|makedirs|touch|truncate|chmod|symlink|copy|move|system\(|subprocess|popen|exec(Sync|File|FileSync|v|ve|vp|l|lp)?\(|spawn|child_process|open\([^)]*,[[:space:]]*['\"][wax+]"
  [[ $unquoted =~ ${head}(python[0-9.]*|node|perl)[[:space:]] ]] && [[ $cmd =~ $inline ]] &&
    [[ ${BASH_REMATCH[4]} =~ $write_call ]] && return 0
  shopt -s nocasematch
  [[ $unquoted =~ $re ]] && return 0
  [[ $cmd =~ $asc ]] && ! [[ $cmd =~ $asc_read ]] && return 0
  [[ $unquoted =~ $apply ]] && ! [[ $unquoted =~ $apply_read ]] && return 0
  [[ $stripped =~ $redirect ]] && return 0
  return 1
}

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
cwd="$(read_field '.cwd')"
[ -z "$cwd" ] && cwd="$PWD"

# The call without what a lead may do (lib/lead-allow.pl). Fails when it cannot
# tell, and on control characters, which the mask uses itself.
without_allowed() {
  # shellcheck source=../lib/shell-mask.sh
  . "$HOOK_DIR/../lib/shell-mask.sh" 2>/dev/null || return 1
  [ "$(LC_ALL=C tr -d '\001-\010\013-\037' <<<"$1")" = "$1" ] || return 1
  mask_shell <<<"$1" | perl "$HOOK_DIR/../lib/lead-allow.pl" "$cwd" 2>/dev/null
}

# CONTEXT.md, docs/decisions.md or docs/roadmap.md at the root of the session's
# repo, or of a worktree of it.
is_coordination_doc() {
  local top common
  [[ $1 == *..* ]] && return 1
  case "$1" in
    /*/CONTEXT.md) top="${1%/CONTEXT.md}" ;;
    /*/docs/decisions.md|/*/docs/roadmap.md) top="${1%/docs/*}" ;;
    *) return 1 ;;
  esac
  [ ! -L "$1" ] && [ ! -L "${1%/*}" ] && [ -z "$(git -C "$top" rev-parse --show-prefix 2>/dev/null)" ] || return 1
  common="$(cd "$top" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null || echo /dev/null)" 2>/dev/null && pwd -P)" || return 1
  [ "$common" = "$(cd "$cwd" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null || echo /dev/null)" 2>/dev/null && pwd -P)" ]
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(read_field '.tool_input.file_path')"
    [ -z "$path" ] && path="$(read_field '.tool_input.notebook_path')"
    case "$path" in
      */.agents/memory/*|*/.planning/*|"$HOME"/.claude/*|/tmp/*|/private/tmp/*|"${TMPDIR:-/tmp/}"*) exit 0 ;;
      # a settings change the user asked for (/update-config) is not execution work
      .claude/settings.json|.claude/settings.local.json|*/.claude/settings.json|*/.claude/settings.local.json) exit 0 ;;
    esac
    [ "$tool" != NotebookEdit ] && is_coordination_doc "$path" && exit 0
    ;;
  Bash)
    cmd="$(read_field '.tool_input.command')"
    left="$(without_allowed "$cmd")" || left="${cmd//$'\x1f'/}"
    # bash needs seconds past this size, and a hook that times out allows
    [ "${#left}" -gt 65536 ] || is_work_command "$left" || exit 0
    ;;
  mcp__claude-in-chrome__computer)
    case "$(read_field '.tool_input.action')" in screenshot|zoom) exit 0 ;; esac
    ;;
  mcp__paper__create_file|mcp__paper__rename_resource|mcp__paper__create_page|mcp__paper__update_pages|\
  mcp__paper__arrange_pages|mcp__paper__set_comment_thread_status|mcp__paper__write_html|\
  mcp__paper__create_artboard|mcp__paper__delete_nodes|mcp__paper__set_text_content|mcp__paper__rename_nodes|\
  mcp__paper__update_styles|mcp__paper__duplicate_nodes|mcp__paper__move_nodes|mcp__paper__create_tokens|\
  mcp__paper__set_tokens) ;;
  mcp__claude-in-chrome__form_input|mcp__claude-in-chrome__navigate|\
  mcp__claude-in-chrome__javascript_tool|mcp__claude-in-chrome__shortcuts_execute|\
  mcp__claude-in-chrome__file_upload|mcp__claude-in-chrome__upload_image|\
  mcp__claude-in-chrome__tabs_create_mcp|mcp__claude-in-chrome__tabs_close_mcp|\
  mcp__claude-in-chrome__resize_window|mcp__claude-in-chrome__browser_batch) ;;
  *) exit 0 ;;
esac

msg="lead-guard: this session is lead (claim role=lead). The lead dispatches and coordinates, it never executes. $tool is work: hand it to a subagent (ai:builder for code, ai:designer for Paper designs and UI, general-purpose for CLI, browser and store consoles; the subagent default model applies; pass model only when another one fits the task). The lead keeps file reads, status commands, MCP reads, screenshots, peer messages, claims, memos, .claude/settings*.json edits, CONTEXT.md, docs/decisions.md and docs/roadmap.md edits, git add of literal files, git worktree remove and git branch -d without force, and gh issue create/edit/comment; browser actions and package runners count as work. Not the lead for this repo? \`ai-kit-claim.sh set role=build\`."
[ "$tool" = Bash ] && msg+=" Writing a memo or temp file (.agents/memory, .planning, ~/.claude, /tmp)? Redirects, mkdir, touch, sed -i, cp and rm pass there with literal paths (\$HOME, \$TMPDIR and ~ resolve, recursive rm in temp dirs only); or use the Write tool. Issue text: --body-file. Every segment of a compound command must pass."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$msg" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
else
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
fi
exit 0
