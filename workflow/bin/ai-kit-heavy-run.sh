#!/usr/bin/env bash
# Run a heavy command (a full test suite) under the machine-wide heavy-run
# lock, so two agents never run one at the same time.
#
#   ai-kit-heavy-run.sh <cmd> [args...]
#
# The lock is the directory ~/.config/ai-kit/heavy-run.lock (mkdir is atomic),
# with a holder file: PID, repo, command. Held: poll every 2 s for up to
# AI_KIT_HEAVY_WAIT seconds (default 600, 0 = refuse at once), then exit 75
# naming the holder. Waiting holds no lock, so killing a waiter is safe. A
# dead PID counts as free, so a wrapper killed with SIGKILL (no trap runs) is
# taken over by the next run. A missing holder counts as held for a minute,
# then as free. Exits with the command's exit code. heavy-run-gate.sh points
# here.
set -uo pipefail

[ $# -gt 0 ] || { echo "usage: ai-kit-heavy-run.sh <cmd> [args...]" >&2; exit 2; }

lock="$HOME/.config/ai-kit/heavy-run.lock"
mkdir -p "${lock%/*}"
top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
busy() { echo "heavy-run: $1; not started, retry when it is done." >&2; exit 75; }
take() {
  mkdir "$lock" 2>/dev/null &&
    printf '%s\n%s\n%s\n' "$$" "${top##*/}" "$*" >"$lock/holder"
}

acquire() {
  take "$@" && return
  pid='' repo='' held=''
  { read -r pid; read -r repo; read -r held; } 2>/dev/null <"$lock/holder"
  if [ -n "$pid" ]; then
    kill -0 "$pid" 2>/dev/null && { why="lock held by ${repo:-?} running '${held:-?}' (pid $pid)"; return 1; }
  elif [ -n "$(find "$lock" -maxdepth 0 -mmin -1 2>/dev/null)" ]; then
    why="another run is taking the lock right now"; return 1
  fi
  # The rename lets only one of several runs clear the same stale lock.
  # shortcut: a clearer that renames after another clearer already re-took the lock moves a live lock; upgrade to a holder re-check after the rename if that is ever seen.
  mv "$lock" "$lock.stale.$$" 2>/dev/null || { why="another run is clearing a stale lock"; return 1; }
  rm -rf "$lock.stale.$$"
  take "$@" || { why="another run took the lock just now"; return 1; }
}

limit="${AI_KIT_HEAVY_WAIT:-600}"
until acquire "$@"; do
  [ "$SECONDS" -lt "$limit" ] || busy "$why"
  [ -n "${told:-}" ] || { echo "heavy-run: $why; waiting up to ${limit}s." >&2; told=1; }
  sleep 2
done

trap 'rm -rf "$lock"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$@"
exit $?
