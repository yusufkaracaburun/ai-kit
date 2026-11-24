#!/usr/bin/env bash
# Claude Code PreToolUse hook on Bash: a full test suite, a production build
# or a dependency install runs only through ai-kit-heavy-run.sh, which holds
# the machine-wide heavy-run lock. A hook alone cannot serialise runs,
# because it exits before the command starts.
#
# Heavy: pest, paratest, phpunit, vitest, jest, playwright, patrol, maestro,
# xcodebuild, gradle(w), vite|next|astro build, npm|pnpm|yarn|bun [run]
# test|build, composer test, php artisan test, and pnpm|npm|yarn|bun
# install|i|ci, anywhere in a chain. eslint and tsc stay free: they run in
# every edit loop, and queuing them behind the lock costs more than their
# peak. Free: a test run with --filter, -t or a test-file argument, a
# segment run through the wrapper, and non-run calls (playwright
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

command -v perl >/dev/null 2>&1 || exit 0
hook_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/shell-mask.sh
. "$hook_dir/../lib/shell-mask.sh" 2>/dev/null || exit 0
masked="$(mask_shell <<<"$cmd")"

# Flags before `test` (pnpm --filter web, npm --prefix app) pick the package, not the tests.
alias_re='^((npm|pnpm|yarn|bun|composer)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*([[:space:]]+run)?|php[[:space:]]+artisan)[[:space:]]+test([[:space:]]+(.*))?$'
# Builds and installs have no test filter, so --filter or -t never frees them.
build_install_re='^(npm|pnpm|yarn|bun)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(install|i|ci|(run[[:space:]]+)?build)([[:space:]]|$)'
launcher_re='^(npm|pnpm|yarn|bun|php)[[:space:]]+((exec|dlx|x)[[:space:]]+)?(.*)$'
runner_re='^([^[:space:]]*/)?(pest|paratest|phpunit|vitest|jest|playwright|patrol|maestro|xcodebuild|gradlew?|vite|next|astro)([[:space:]]+(.*))?$'

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
  local wrapper at
  if [ -f "$hook_dir/../bin/ai-kit-heavy-run.sh" ]; then
    wrapper="$(cd "$hook_dir/../bin" && pwd)/ai-kit-heavy-run.sh"
  else
    wrapper="$(cd "$hook_dir/.." && pwd)/ai-kit-heavy-run.sh"
  fi
  at="$1"
  [[ $2 =~ ^((([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|\{|!|then|do)[[:space:]]+)*) ]] && at=$((at + ${#BASH_REMATCH[1]}))
  jq -n --arg r "heavy-run: test suites, builds and installs run under the machine-wide lock. Rerun as: $(
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
  while [[ $seg =~ $SHELL_PREFIX_RE ]]; do seg="${BASH_REMATCH[3]}"; done
  [ -z "$seg" ] && continue
  [[ $seg =~ $build_install_re ]] && deny "$start" "$shown"
  if [[ $seg =~ $alias_re ]]; then
    args="${BASH_REMATCH[7]}"
  else
    rest="$seg"
    [[ $rest =~ $launcher_re ]] && rest="${BASH_REMATCH[4]}"
    [[ $rest =~ $runner_re ]] || continue
    tool="${BASH_REMATCH[2]}" args="${BASH_REMATCH[4]}"
    case "$tool $args " in
      "playwright install "*|"playwright show-report "*|"playwright codegen "*|*" --version "*|*" -version "*|"xcodebuild -list "*|"xcodebuild "*" -list "*) continue ;;
      "vite build "*|"next build "*|"astro build "*) deny "$start" "$shown" ;;
      "vite "*|"next "*|"astro "*) continue ;;
    esac
  fi
  filtered "$args" || deny "$start" "$shown"
done
exit 0
