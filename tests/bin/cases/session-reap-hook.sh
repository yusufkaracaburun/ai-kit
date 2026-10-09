#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/session-reap.sh"

# Real processes and real `ps -E`. Targets are node timers carrying a fake
# AI_KIT_SESSION_ID; /bin/sleep is an Apple platform binary whose env ps
# cannot read. The sweep is machine-wide, so the hook runs with a `ps` on
# PATH that is the real ps with its rows limited to pids this test started:
# a real orphan from a real session can never be a target. HOME is faked so
# the registry is ours.
TMP_H=$(mktemp -d)
export HOME="$TMP_H/home"
export XDG_STATE_HOME="$TMP_H/state"
REG="$HOME/.claude/sessions"
LOG="$XDG_STATE_HOME/ai-kit/session-reap.log"
mkdir -p "$REG" "$TMP_H/shim"
KEEP="$TMP_H/pids"
: > "$KEEP"
REAL_PS="$(command -v ps)"
cat > "$TMP_H/shim/ps" <<EOF
#!/usr/bin/env bash
"$REAL_PS" "\$@" | awk -v keep=" \$(tr '\n' ' ' < "$KEEP") " 'index(keep, " " \$1 " ")'
EOF
chmod +x "$TMP_H/shim/ps"

cleanup() {
  local p
  while read -r p; do
    [ -z "$p" ] || kill -KILL "$p" 2>/dev/null || true
  done < "$KEEP"
  rm -rf "$TMP_H"
}
trap cleanup EXIT

NODE="$(command -v node || true)"
TIMER='setInterval(() => {}, 1000)'

alive() {
  local s
  s="$("$REAL_PS" -o stat= -p "$1" 2>/dev/null | tr -d ' ')"
  [ -n "$s" ] && [ "${s#Z}" = "$s" ]
}

# orphan <sid|-> : ORPHAN = pid of a node timer whose parent already exited;
# "-" starts it without any marker.
orphan() {
  local f="$TMP_H/pid.$RANDOM"
  if [ "$1" = - ]; then
    ( env -u AI_KIT_SESSION_ID "$NODE" -e "$TIMER" >/dev/null 2>&1 & echo $! > "$f" )
  else
    ( env AI_KIT_SESSION_ID="$1" "$NODE" -e "$TIMER" >/dev/null 2>&1 & echo $! > "$f" )
  fi
  ORPHAN=$(cat "$f")
  echo "$ORPHAN" >> "$KEEP"
  sleep 0.3
}

registry() {
  printf '{"pid":%s,"sessionId":"%s","cwd":"/x","name":"x","status":"idle"}\n' "$2" "$1" > "$REG/$1.json"
}

start() { printf '{"session_id":"own-1","hook_event_name":"SessionStart","source":"%s"}' "${1:-startup}"; }
end() { printf '{"session_id":"%s","hook_event_name":"SessionEnd","reason":"%s"}' "$1" "${2:-other}"; }
fire() { PATH="$TMP_H/shim:$PATH" bash "$HOOK" <<<"$1"; }

if [ -z "$NODE" ]; then
  echo "  skip: no node binary to carry a readable env"
  print_summary_and_exit
fi
orphan probe-1
if [ "$("$REAL_PS" -o ppid= -p "$ORPHAN" | tr -d ' ')" != 1 ] ||
   ! "$REAL_PS" -Eww -o command= -p "$ORPHAN" 2>/dev/null | grep -q "AI_KIT_SESSION_ID=probe-1"; then
  echo "  skip: no pid-1 reparenting or env unreadable via ps -E on this host"
  print_summary_and_exit
fi
kill -KILL "$ORPHAN"

registry own-1 "$$"
registry live-1 "$$"
registry gone-1 99999999

echo "=== session-reap: startup kills orphans of dead sessions ==="
# section: session-reap-startup
orphan dead-1; O_DEAD=$ORPHAN
orphan gone-1; O_GONE=$ORPHAN
orphan live-1; O_LIVE=$ORPHAN
orphan -; O_BARE=$ORPHAN
env AI_KIT_SESSION_ID=dead-1 "$NODE" -e "$TIMER" >/dev/null 2>&1 &
CHILD=$!
disown "$CHILD"
echo "$CHILD" >> "$KEEP"
fire "$(start)"
assert "orphan of a session with no registry entry is killed" '! alive "$O_DEAD"'
assert "orphan of a registry entry whose pid is dead is killed" '! alive "$O_GONE"'
assert "orphan of a live session survives" 'alive "$O_LIVE"'
assert "orphan without a marker survives" 'alive "$O_BARE"'
assert "non-orphan with a dead sid survives" 'alive "$CHILD"'

echo "=== session-reap: kills are logged ==="
# section: session-reap-log
assert "log line: ts event pid sid command" \
  'grep -qE "^[0-9TZ:-]+ SessionStart $O_DEAD dead-1 .*node$" "$LOG"'
assert "survivors are not logged" '! grep -q " $O_LIVE " "$LOG"'

echo "=== session-reap: triggers ==="
# section: session-reap-triggers
orphan dead-2; O_SRC=$ORPHAN
for src in compact clear resume; do
  fire "$(start "$src")"
  assert "SessionStart source=$src -> dead-sid orphan survives" 'alive "$O_SRC"'
done
for reason in clear resume; do
  fire "$(end live-1 "$reason")"
  assert "SessionEnd reason=$reason -> ending-sid orphan survives" 'alive "$O_LIVE"'
done
fire "$(end live-1)"
assert "SessionEnd reason=other -> orphan of the ending session is killed" '! alive "$O_LIVE"'
assert "SessionEnd also sweeps dead sessions" '! alive "$O_SRC"'
assert "SessionEnd kill is logged" 'grep -q " SessionEnd $O_LIVE live-1 " "$LOG"'

echo "=== session-reap: registry unreadable fails closed ==="
# section: session-reap-noreg
orphan dead-3; O_NOREG=$ORPHAN
orphan ending-1; O_ENDING=$ORPHAN
mv "$REG" "$REG.away"
fire "$(start)"
assert "startup without registry -> dead-sid orphan survives" 'alive "$O_NOREG"'
fire "$(end ending-1)"
assert "SessionEnd without registry -> ending-sid orphan still dies" '! alive "$O_ENDING"'
assert "SessionEnd without registry -> dead-sid orphan survives" 'alive "$O_NOREG"'
mv "$REG.away" "$REG"

echo "=== session-reap: malformed input ==="
# section: session-reap-malformed
set +e
OUT_BAD=$(bash "$HOOK" <<<"not json" 2>&1); BAD_RC=$?
OUT_EMPTY=$(bash "$HOOK" </dev/null 2>&1); EMPTY_RC=$?
set -e
assert "garbage payload exits 0 silent" '[ "$BAD_RC" -eq 0 ] && [ -z "$OUT_BAD" ]'
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$OUT_EMPTY" ]'

echo "=== session-reap: plugin delivery ==="
# section: session-reap-plugin
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
for ev in SessionStart SessionEnd; do
  assert "hooks.json registers session-reap on $ev" \
    'python3 -c "
import json
d = json.load(open(\"$HOOKS_JSON\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"$ev\"] for h in b[\"hooks\"]]
assert \"\${CLAUDE_PLUGIN_ROOT}/hooks/session-reap.sh\" in cmds, cmds
"'
done
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'

print_summary_and_exit
