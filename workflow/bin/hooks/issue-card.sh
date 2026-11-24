#!/usr/bin/env bash
# Claude Code hook on Bash for `gh issue create`, both events:
#   PreToolUse   denies a body that lacks the H2 headings of every .md template
#                in the repo's .github/ISSUE_TEMPLATE, or that it cannot read.
#                A body line `<!-- card: other -->` passes.
#   PostToolUse  gives the new issue its type (from the matched template),
#                Priority and Backlog through ai-kit-issue-meta.sh
#                --only-unset. A failure is a message, never a block.
#
# A create in another repo (--repo, a leading cd), GH_REPO= in the call and
# `--web` are let through. lib/issue-card.pl holds the parsing for both events,
# and the known holes.
#
# Off by default: fires only where .ai-kit-setup has branches.issue_card_hook
# = wired and the repo has .md templates with headings. Always exits 0; fails
# open without jq or perl (silent) and past the 2s parser alarm (a message).
# Wired in workflow/hooks/hooks.json.
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[[ $payload == *issue* ]] || exit 0
command -v jq >/dev/null 2>&1 && command -v perl >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)"
[[ $cmd =~ gh[[:space:]]+issue[[:space:]]+(create|new) && $cmd != *GH_REPO=* ]] || exit 0

# Marker, then templates; nothing is parsed before both are there.
cwd="$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)"
dir="${cwd:-$PWD}"
cd_re="^[[:space:]]*cd[[:space:]]+(\"([^\"\$\`\\]+)\"|'([^']+)'|([^][:space:]\"'\$\`\;&|()<>*?[]+))[[:space:]]*(&&|;|"$'\n'")"
if [[ $cmd =~ $cd_re ]]; then
  to="${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
  [[ $to == \~/* ]] && to="$HOME${to#\~}"
  [[ $to == /* ]] || to="$dir/$to"
  [ -d "$to" ] && dir="$to"
fi
top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/setup-marker.sh
. "$HOOK_DIR/../lib/setup-marker.sh" 2>/dev/null || exit 0
marker_hook_on "$top" issue-card skipped || exit 0
templates=("$top"/.github/ISSUE_TEMPLATE/*.md)
[ -f "${templates[0]}" ] || exit 0
# shellcheck source=../lib/shell-mask.sh
. "$HOOK_DIR/../lib/shell-mask.sh" 2>/dev/null || exit 0

origin="$(git -C "$top" remote get-url origin 2>/dev/null)"
origin="${origin%/}" origin="${origin%.git}"
[[ $origin =~ ([^/:]+/[^/]+)$ ]] && origin="$(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}")" || origin=""
not_checked() {
  echo "issue-card: the parser failed or timed out, this gh issue create was not checked" >&2
  exit 0
}
# URL="$(gh issue create ...)" is read as URL=$(gh issue create ...).
unwrap='BEGIN { alarm 2 } s/"\$\((?=\s*gh\s+issue\s)((?:[^()"\x27]++|"[^"]*+"|\x27[^\x27]*+\x27)*+)\)"/\$($1)/g'
masked="$(perl -0777 -pe "$unwrap" <<<"$cmd" | mask_shell)" || not_checked
found="$(perl "$HOOK_DIR/../lib/issue-card.pl" "$SHELL_PREFIX_RE" "$dir" "$origin" "${templates[@]}" <<<"$masked")" || not_checked

# card_type <template>: the issue type its file name stands for, empty if unknown
card_type() {
  case "${1##*/}" in
    epic.*) echo Epic ;;
    story.*) echo Story ;;
    bug.*) echo Bug ;;
    task.*|spike.*|idea.*) echo Task ;;
  esac
}

reasons="" types=() parents=()
while IFS=$'\x1f' read -r kind file detail parent; do
  type=""
  case "$kind" in
    '') continue ;;
    ok) type="$(card_type "$file")" ;;
    unreadable) reasons+="issue-card [unreadable]: cannot read the body of this gh issue create: $detail. Write the body to a file in an earlier call and pass its literal path, for example: gh issue create --title \"Title\" --body-file /tmp/issue-body.md"$'\n' ;;
    missing) reasons+="issue-card [missing headings]: the body lacks $detail. Closest template: ${file#"$top"/}. Keep every ## heading of one template in .github/ISSUE_TEMPLATE, then create the issue again."$'\n' ;;
  esac
  types+=("$type") parents+=("$parent")
done <<<"$found"

if [ "$(jq -r '.hook_event_name // empty' <<<"$payload" 2>/dev/null)" != PostToolUse ]; then
  [ -z "$reasons" ] || jq -n --arg r "${reasons%$'\n'}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
fi

[ "${#types[@]}" -gt 0 ] && [ -n "$origin" ] || exit 0
urls=() left="$(jq -r '.tool_response | if type == "object" then .stdout // empty else empty end' <<<"$payload" 2>/dev/null)"
url_re='https://github\.com/([^/[:space:]]+/[^/[:space:]]+)/issues/[0-9]+(.*)'
while [[ $left =~ $url_re ]]; do
  left="${BASH_REMATCH[2]}" url="${BASH_REMATCH[0]%"${BASH_REMATCH[2]}"}"
  [[ $left == '#'* || $(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}") != "$origin" ]] && continue
  [[ " ${urls[*]-} " == *" $url "* ]] || urls+=("$url")
done

# Runs a command in its own process group, killed as a whole at the limit.
# shellcheck disable=SC2016
limit='my $t = shift; my $p = fork // exit 1; if (!$p) { setpgrp(0, 0); exec @ARGV; exit 127 }
  $SIG{ALRM} = sub { kill "TERM", -$p; print "issue-meta: timed out after ${t}s\n"; exit 124 };
  alarm $t; waitpid $p, 0; exit $? >> 8'
out="" spent=$SECONDS
if [ "${#urls[@]}" -ne "${#types[@]}" ]; then
  out="found ${#urls[@]} issue URLs for ${#types[@]} gh issue create; nothing set. Run ai-kit-issue-meta.sh on the new issue."
else
  for i in "${!urls[@]}"; do
    # hooks.json cancels the hook at 60s and drops its output.
    ((SECONDS - spent < 35)) || { out+="out of time, nothing set on ${urls[i]}"$'\n'; continue; }
    out+="$(perl -e "$limit" "${AI_KIT_ISSUE_CARD_TIMEOUT:-20}" bash "$HOOK_DIR/../ai-kit-issue-meta.sh" "${urls[i]}" --only-unset --status Backlog \
      ${types[i]:+--type "${types[i]}"} ${parents[i]:+--parent "${parents[i]}"} 2>&1)"$'\n'
  done
fi
[ -z "${out//$'\n'/}" ] || jq -n --arg c "issue-card: ${out%$'\n'}" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
