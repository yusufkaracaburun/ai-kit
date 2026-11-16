#!/usr/bin/env bash
# Claude Code PreToolUse hook on Bash: a full test suite runs only through
# ai-kit-heavy-run.sh, which holds the machine-wide heavy-run lock. A hook
# alone cannot serialise runs, because it exits before the command starts.
#
# Heavy: pest, paratest, phpunit, vitest, jest, playwright, patrol, maestro,
# xcodebuild, gradle(w), and npm|pnpm|yarn|bun [run] test, composer test,
# php artisan test, anywhere in a chain. Free: --filter, -t, a test-file
# argument, a segment run through the wrapper, and non-run calls (playwright
# install|show-report|codegen, --version, xcodebuild -list). No override: the
# user runs a suite in a terminal or with `!`.
#
# Not marker-gated: the lock is machine-wide, so every repo takes it. Always
# exits 0; fails open (silent) without jq or perl. Wired in
# workflow/hooks/hooks.json.
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)"
[ -z "$cmd" ] && exit 0

# Quoted text keeps its separators and spaces masked, so a commit message
# naming `pnpm test` is never a segment of its own.
command -v perl >/dev/null 2>&1 || exit 0
masked="$(perl -0777 -pe 's/("[^"]*"|\x27[^\x27]*\x27)/my $q = $1; $q =~ tr{;&|()\n \t}{\x01-\x08}; $q/ge' <<<"$cmd")"

prefix_re='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|timeout([[:space:]]+[0-9]+[smh]?)?|time|env|command|nice|exec|sudo|npx|bunx|pnpx|\{|!|then|do)[[:space:]]+(.*)$'
# Flags before `test` (pnpm --filter web, npm --prefix app) pick the package, not the tests.
alias_re='^((npm|pnpm|yarn|bun|composer)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*([[:space:]]+run)?|php[[:space:]]+artisan)[[:space:]]+test([[:space:]]+(.*))?$'
launcher_re='^(npm|pnpm|yarn|bun|php)[[:space:]]+((exec|dlx|x)[[:space:]]+)?(.*)$'
runner_re='^([^[:space:]]*/)?(pest|paratest|phpunit|vitest|jest|playwright|patrol|maestro|xcodebuild|gradlew?)([[:space:]]+(.*))?$'

filtered() {
  local w words
  [ -n "$1" ] || return 1
  read -r -a words <<<"$1"
  for w in "${words[@]}"; do
    case "$w" in
      --filter|--filter=*|-t|-t*|*.test.*|*.spec.*|*Test.php|*Test.php::*|*_test.*) return 0 ;;
    esac
  done
  return 1
}

deny() {
  local hook_dir wrapper at
  hook_dir="$(cd "$(dirname "$0")" && pwd)"
  if [ -f "$hook_dir/../bin/ai-kit-heavy-run.sh" ]; then
    wrapper="$(cd "$hook_dir/../bin" && pwd)/ai-kit-heavy-run.sh"
  else
    wrapper="$(cd "$hook_dir/.." && pwd)/ai-kit-heavy-run.sh"
  fi
  at="$1"
  [[ $2 =~ ^((([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|\{|!|then|do)[[:space:]]+)*) ]] && at=$((at + ${#BASH_REMATCH[1]}))
  jq -n --arg r "heavy-run: full test suites run under the machine-wide lock. Rerun as: $(
    tr '\001\002\003\004\005\006\007\010' ';&|()\n \t' <<<"${masked:0:at}$wrapper ${masked:at}")" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

split_re=$'^([^;&|()\n]*)([;&|()\n]*)'
off=0 left="$masked"
while [ -n "$left" ]; do
  [[ $left =~ $split_re ]]
  seg="${BASH_REMATCH[1]}" step=$((${#BASH_REMATCH[1]} + ${#BASH_REMATCH[2]}))
  left="${left:step}" start=$off off=$((off + step))
  lead="${seg%%[![:space:]]*}"
  seg="${seg#"$lead"}" start=$((start + ${#lead}))
  seg="${seg%"${seg##*[![:space:]]}"}"
  [[ $seg == *ai-kit-heavy-run.sh* ]] && continue
  shown="$seg"
  while [[ $seg =~ $prefix_re ]]; do seg="${BASH_REMATCH[3]}"; done
  [ -z "$seg" ] && continue
  if [[ $seg =~ $alias_re ]]; then
    args="${BASH_REMATCH[7]}"
  else
    rest="$seg"
    [[ $rest =~ $launcher_re ]] && rest="${BASH_REMATCH[4]}"
    [[ $rest =~ $runner_re ]] || continue
    tool="${BASH_REMATCH[2]}" args="${BASH_REMATCH[4]}"
    case "$tool $args " in
      "playwright install "*|"playwright show-report "*|"playwright codegen "*|*" --version "*|*" -version "*|"xcodebuild -list "*|"xcodebuild "*" -list "*) continue ;;
    esac
  fi
  filtered "$args" || deny "$start" "$shown"
done
exit 0
