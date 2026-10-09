#!/usr/bin/env bash
# Claude Code SessionStart + SessionEnd hook: kill what a dead session left
# running.
#
# Depends on AI_KIT_SESSION_ID, which peer-sessions-check.sh exports through
# CLAUDE_ENV_FILE, so everything a session starts carries its id in its env.
# A target has ppid 1, this user's uid, and AI_KIT_SESSION_ID in its env
# (read with `ps -E`) naming either the ending session (SessionEnd) or a
# session with no live entry in ~/.claude/sessions (both events). Registry
# unreadable: only the ending session. No readable env: never a target.
# TERM, then KILL whatever is alive ~2s later; each kill is logged to
# ${XDG_STATE_HOME:-~/.local/state}/ai-kit/session-reap.log.
#
# Runs on SessionStart source=startup and on SessionEnd unless reason is
# clear/resume. Silent, always exit 0. Ships in workflow/hooks/hooks.json.

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

# Same reader as bin/ai-kit-claim.sh: flat single-line JSON from Claude Code.
registry_get() {
  sed -n 's/.*"'"$1"'":"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' "$2" 2>/dev/null | head -1
}

# Zombies count as gone: their parent reaps them, there is nothing to kill.
alive() {
  [ $# -gt 0 ] || return 0
  ps -o pid=,stat= -p "$(IFS=,; echo "$*")" 2>/dev/null | awk '$2 !~ /^Z/ {print $1}'
}

reap() {
  local left i
  [ $# -gt 0 ] || return 0
  kill -TERM "$@" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do
    left="$(alive "$@")"
    [ -n "$left" ] || return 0
    sleep 0.2
  done
  # shellcheck disable=SC2086
  kill -KILL $left 2>/dev/null
}

# sweep <event> <ending sid or empty>
sweep() {
  local event="$1" ending="$2" reg f pid live="" scan=0 log targets sid pids=()
  reg="$HOME/.claude/sessions"
  if [ -d "$reg" ] && [ -r "$reg" ]; then
    scan=1
    live=" $(read_field '.session_id') "
    for f in "$reg"/*.json; do
      [ -f "$f" ] || continue
      pid="$(registry_get pid "$f")"
      { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; } && live+="$(registry_get sessionId "$f") "
    done
  fi
  [ "$scan" = 1 ] || [ -n "$ending" ] || return 0

  # ps -E appends the env after the args; the last marker on the line wins.
  targets="$(ps -A -Eww -o pid=,ppid=,uid=,command= 2>/dev/null |
    awk -v uid="$(id -u)" -v ending="$ending" -v live="$live" -v scan="$scan" '
      $2 == 1 && $3 == uid {
        sid = ""; rest = $0
        while (match(rest, /AI_KIT_SESSION_ID=[A-Za-z0-9_-]+/)) {
          sid = substr(rest, RSTART + 18, RLENGTH - 18); rest = substr(rest, RSTART + RLENGTH)
        }
        if (sid != "" && (sid == ending || (scan && index(live, " " sid " ") == 0))) print $1, sid
      }')"
  [ -n "$targets" ] || return 0

  log="${XDG_STATE_HOME:-$HOME/.local/state}/ai-kit/session-reap.log"
  mkdir -p "$(dirname "$log")" 2>/dev/null
  while read -r pid sid; do
    # comm, not command: the command line carries the env, secrets included.
    printf '%s %s %s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$pid" "$sid" \
      "$(ps -o pid=,comm= -p "$pid" 2>/dev/null | sed 's/^ *[0-9]* //')" >> "$log" 2>/dev/null
    pids+=("$pid")
  done <<<"$targets"
  reap "${pids[@]}"
}

case "$(read_field '.hook_event_name')" in
  SessionStart) [ "$(read_field '.source')" = startup ] && sweep SessionStart "" ;;
  SessionEnd)
    case "$(read_field '.reason')" in
      clear|resume) ;;
      *) sweep SessionEnd "$(read_field '.session_id')" ;;
    esac ;;
esac
exit 0
