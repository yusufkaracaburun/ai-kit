#!/usr/bin/env bash
# Claude Code PreToolUse hook on Bash: `git commit` and `git push` need an
# APPROVE from /ai:review for exactly the tree they ship.
#
#   review-gate.sh                                       hook mode, payload on stdin
#   review-gate.sh --approve [--skip "<reason>"] [<dir>] write the marker
#
# The key is `git write-tree` of the index, kept as line 1 of
# <git-dir>/ai-kit/review-ok (line 2: date and reason). The git-dir is per
# worktree, so an approval in one worktree never unlocks another. Only the
# review skill writes it, after the verify pass re-derives APPROVE. `--skip`
# is the one override, a user-only step, logged to <git-dir>/ai-kit/gate-log.
# A commit is checked against the index, a push against HEAD^{tree}.
# When the hook cannot tell which tree ships to which repo (a quoted or
# variable target, a shell wrapper, staging in the same command) it denies
# and names the plain form. It does not parse shell beyond that.
#
# Known holes:
# - scripts that commit internally (bin/release.sh) and a user's `!git commit`
#   passthrough never reach this hook; Cursor ships no hooks, so no gate there;
# - `--approve` is an honour system: any agent can run it, only `--skip` is
#   logged, and a non-lead subagent can write the marker file directly;
# - a push compares HEAD only: other refspecs, `--all` and `--tags` are not.
#
# Gated on .ai-kit-setup branches.review_gate_hook (default wired); silent
# without a marker. Always exits 0 in hook mode. Fails open (silent) without
# jq or python3, on purpose. Wired for the plugin in workflow/hooks/hooks.json.
set -uo pipefail

if [ "${1:-}" = --approve ]; then
  shift
  reason="review APPROVE" skip=""
  if [ "${1:-}" = --skip ]; then
    skip="${2:-}"
    [ -n "$skip" ] || { echo 'usage: review-gate.sh --approve [--skip "<reason>"] [<dir>]' >&2; exit 2; }
    reason="skip: $skip"
    shift 2
  fi
  d="${1:-$PWD}"
  gd="$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null)" || { echo "review-gate: $d is not a git repo" >&2; exit 1; }
  tree="$(git -C "$d" write-tree)" || exit 1
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$gd/ai-kit"
  printf '%s\n%s %s\n' "$tree" "$now" "$reason" >"$gd/ai-kit/review-ok"
  [ -n "$skip" ] && printf '%s %s %s\n' "$now" "$tree" "$skip" >>"$gd/ai-kit/gate-log"
  echo "review-gate: approved tree ${tree:0:7} ($reason)"
  exit 0
fi

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/setup-marker.sh
. "$HOOK_DIR/../bin/lib/setup-marker.sh" 2>/dev/null || . "$HOOK_DIR/../lib/setup-marker.sh" 2>/dev/null || exit 0

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

cmd="$(read_field '.tool_input.command')"
[ -z "$cmd" ] && exit 0
cwd="$(read_field '.cwd')"
[ -z "$cwd" ] && cwd="$PWD"

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$1" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  else
    local esc="${1//\\/\\\\}"
    esc="${esc//\"/\\\"}"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
  fi
  exit 0
}

# Succeeds when `git commit <args>` would commit more than the staged index.
outside_index() {
  local w i takes=0 words
  read -r -a words <<<"$1"
  for w in "${words[@]}"; do
    if ((takes)); then takes=0; continue; fi
    case "$w" in
      --|--all|--include|--only|--pathspec-from-file*) return 0 ;;
      --author|--date|--message|--file|--reuse-message|--reedit-message|--fixup|--squash|--template|--cleanup|--trailer) takes=1 ;;
      *'>'|*'<') takes=1 ;;
      *'>'*|*'<'*|--*) ;;
      -*)
        for ((i = 1; i < ${#w}; i++)); do
          case "${w:i:1}" in
            a|i|o) return 0 ;;
            m|F|C|c|t) [ $((i + 1)) -eq ${#w} ] && takes=1; break ;;
          esac
        done
        ;;
      *) return 0 ;;
    esac
  done
  return 1
}

# check <dir> <verb> <args>: deny unless the tree it ships carries an APPROVE
check() {
  local dir="$1" gd tree
  gd="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)" || return 0
  marker_hook_on "$(git -C "$dir" rev-parse --show-toplevel)" review-gate wired || return 0
  if [ "$2" = commit ]; then
    outside_index "$3" &&
      deny "review-gate: git commit with -a, -i, -o or a pathspec ships files the review never saw: stage explicitly, then /ai:review."
    ((staged)) && deny "review-gate: this command changes the index before it commits, so the committed tree is not the reviewed one: stage in a separate command, then /ai:review."
    tree="$(git -C "$dir" write-tree 2>/dev/null)" what="staged tree"
  else
    [[ " $3 " =~ [[:space:]](-d|--delete)[[:space:]] ]] && return 0
    ((committed)) && return 0
    ((moved)) && deny "review-gate: this command moves HEAD before it pushes. After a rebase, pull or merge, run /ai:review on the result, then push in a separate command."
    # shortcut: compares HEAD only; other refspecs, --all and --tags are not compared.
    tree="$(git -C "$dir" rev-parse 'HEAD^{tree}' 2>/dev/null)" what="HEAD tree"
  fi
  [ -n "$tree" ] && [ "$tree" = "$(head -1 "$gd/ai-kit/review-ok" 2>/dev/null)" ] && return 0
  deny "review-gate: $what ${tree:0:7} has no APPROVE. Run /ai:review (verdict APPROVE), then retry; a rebase, pull or merge needs a fresh review before push.$skip_hint"
}

skip_hint=' Override is a user-only step: review-gate.sh --approve --skip "<reason>" (logged).'

# A form the hook cannot resolve is gated when the cwd's repo or the session's project is.
gated_here() {
  local d top
  for d in "$cwd" "${CLAUDE_PROJECT_DIR:-}"; do
    [ -n "$d" ] || continue
    top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || top="$d"
    marker_hook_on "$top" review-gate wired && return 0
  done
  return 1
}
unsure() {
  gated_here && deny "review-gate: cannot tell which repo this $1 targets: use an unquoted absolute path: git -C /abs/path $1."
}

# Heredoc bodies are data.
code="$(perl -0777 -pe 's/<<-?[ \t]*([\x27"]?)(\w+)\1([^\n]*)\n(?:.*?\n)?[ \t]*\2[ \t]*(?=\n|$)/$3/gs' <<<"$cmd")"

# A shell wrapper hides the git command inside one quoted argument.
wrap_re='(^|[^[:alnum:]_.-])(bash|sh|zsh|dash)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*c[A-Za-z]*[[:space:]]+(.*)'
if [[ $code =~ $wrap_re ]] && [[ ${BASH_REMATCH[4]} =~ git[^\;\&\|]*[[:space:]](commit|push)([[:space:]\"\']|$) ]]; then
  gated_here && deny "review-gate: run git directly, not through a shell wrapper, so the gate can see what ships."
fi

# A quoted plain token (a path, a word) keeps its text so `-C "/repo"` still
# resolves; any other quoted text becomes "". A command substitution becomes
# `$SUB` in place and its body a line of its own.
unquoted="$(perl -0777 -pe '
  s/"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27/my $t = defined $1 ? $1 : $2; $t =~ m{^[\w.\/~\$\@%+=:,-]+$} ? $t : q{""}/ge;
  my @sub;
  s/`([^`]*)`|\$\(([^()]*)\)/push @sub, (defined $1 ? $1 : $2); q{$SUB}/ge;
  $_ .= "\n" . join("\n", @sub) . "\n";
' <<<"$code")"
prefix_re='^[[:space:]]*(\{|!|then|do|else|time|env|command|eval|exec|nice|sudo|xargs)[[:space:]]+(.*)$'
git_re='^[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*)([^[:space:]]*/)?git(([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace)[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?|-[A-Za-z]))*)[[:space:]]+([a-z-]+)([[:space:]]+(.*))?$'
cd_re='^[[:space:]]*(cd|pushd)([[:space:]]+([^[:space:]]*))?[[:space:]]*$'
c_re='-C[[:space:]]+([^[:space:]]+)(.*)'
# resolve <base> <dir>: prints the path, fails on a target the hook cannot know
resolve() {
  case "$2" in
    ''|*'$'*|*'`'*|'""'|'~'[!/]*) return 1 ;;
    /*) echo "$2" ;;
    '~'*) echo "$HOME${2#\~}" ;;
    *) echo "$1/$2" ;;
  esac
}
nl=$'\n'
base="$cwd" base_ok=1 staged=0 committed=0 moved=0
while IFS= read -r seg; do
  seg="${seg%%)*}"
  while [[ $seg =~ $prefix_re ]]; do seg="${BASH_REMATCH[2]}"; done
  if [[ $seg =~ $cd_re ]]; then
    base="$(resolve "$cwd" "${BASH_REMATCH[3]}")" && base_ok=1 || base_ok=0
    continue
  fi
  [[ $seg =~ $git_re ]] || continue
  envs="${BASH_REMATCH[1]}" globals="${BASH_REMATCH[4]}" verb="${BASH_REMATCH[9]}" args="${BASH_REMATCH[11]}"
  [[ $verb =~ ^(switch|checkout)$ && $args =~ ^-[cCbB][[:space:]]+[^[:space:]]+[[:space:]]*$ ]] && continue
  case "$verb" in
    commit|push) ;;
    add|rm|mv|apply|restore|stash) staged=1; continue ;;
    reset|checkout|switch|merge|pull|rebase|cherry-pick|revert|am) staged=1 moved=1 committed=0; continue ;;
    *) continue ;;
  esac
  [[ $envs$globals =~ GIT_(DIR|WORK_TREE|INDEX_FILE)=|--git-dir|--work-tree ]] && { unsure "$verb"; continue; }
  dir="$base" ok="$base_ok"
  while ((ok)) && [[ $globals =~ $c_re ]]; do
    dir="$(resolve "$dir" "${BASH_REMATCH[1]}")" || ok=0
    globals="${BASH_REMATCH[2]}"
  done
  if ((ok)) && [ "$dir" != "$cwd" ] && ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then ok=0; fi
  ((ok)) || { unsure "$verb"; continue; }
  check "$dir" "$verb" "$args"
  [ "$verb" = commit ] && committed=1 moved=0
done <<<"${unquoted//[;&|(]/$nl}"
exit 0
