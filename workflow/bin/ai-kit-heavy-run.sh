#!/usr/bin/env bash
# Run a heavy command (a full test suite) under the machine-wide heavy-run
# lock, so two agents never run one at the same time.
#
#   ai-kit-heavy-run.sh <cmd> [args...]
#
# The lock is the directory ~/.config/ai-kit/heavy-run.lock (mkdir is atomic),
# with a holder file: PID, repo, command. Held by a live PID: exit 75 at once,
# naming the holder; no waiting. A dead PID counts as free, so a wrapper killed
# with SIGKILL (no trap runs) is taken over by the next run. A missing holder
# counts as held for a minute, then as free. Exits with the command's exit
# code. heavy-run-gate.sh points here.
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

if ! take "$@"; then
  { read -r pid; read -r repo; read -r held; } 2>/dev/null <"$lock/holder"
  if [ -n "${pid:-}" ]; then
    kill -0 "$pid" 2>/dev/null && busy "lock held by ${repo:-?} running '${held:-?}' (pid $pid)"
  elif [ -n "$(find "$lock" -maxdepth 0 -mmin -1 2>/dev/null)" ]; then
    busy "another run is taking the lock right now"
  fi
  # The rename lets only one of several runs clear the same stale lock.
  # shortcut: a clearer that renames after another clearer already re-took the lock moves a live lock; upgrade to a holder re-check after the rename if that is ever seen.
  mv "$lock" "$lock.stale.$$" 2>/dev/null || busy "another run is clearing a stale lock"
  rm -rf "$lock.stale.$$"
  take "$@" || busy "another run took the lock just now"
fi

trap 'rm -rf "$lock"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$@"
exit $?
