#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# autonomous-heartbeat.sh appends a tick line every --interval seconds to a
# progress file until it receives TERM/INT, then appends a final "stopped"
# line and exits 0. Runs against a throwaway progress file — no $HOME
# involvement.
#
# NOT COVERED: real multi-minute intervals (default 60s) — tests run with
# --interval 1 to keep the suite fast.

HELPER="$AIKIT/bin/autonomous-heartbeat.sh"

echo "=== lifecycle: ticks, nested-dir creation, clean TERM shutdown ==="
H=$(mktemp -d)
PID=""
# The script under test is an unbounded `while true; sleep` loop. Without this
# trap, any early abort — a failing assert, or run-all.sh being interrupted
# while this case is in flight — orphans a process that ticks every second
# forever, writing into a temp dir that no longer exists.
trap 'if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; fi; rm -rf "$H"' EXIT

# Bounded run for the argument-validation cases below. Those exercise paths
# that are supposed to exit immediately; if validation ever regresses, the
# script falls through to its infinite loop. run-all.sh has no per-case
# timeout, so an unbounded call there would wedge the entire suite instead of
# failing one assertion.
run_bounded() {
  local limit="$1"; shift
  local rc=0 pid watcher
  "$@" 2>/dev/null &
  pid=$!
  ( sleep "$limit"; kill -9 "$pid" 2>/dev/null ) &
  watcher=$!
  # disown so killing the watchdog below does not print bash's own
  # "Terminated" job-control notice into the case output.
  disown "$watcher" 2>/dev/null || true
  wait "$pid" 2>/dev/null || rc=$?
  kill "$watcher" 2>/dev/null || true
  return "$rc"
}

PROGRESS="$H/nested/dir/progress.txt"
bash "$HELPER" 42 "$PROGRESS" --interval 1 &
PID=$!
sleep 2.2
assert "progress dir auto-created" '[ -d "$(dirname "$PROGRESS")" ]'
assert "at least 2 brewing ticks logged" \
  '[ "$(grep -cE "heartbeat.*brewing" "$PROGRESS" 2>/dev/null || echo 0)" -ge 2 ]'
# Anchored on the tab-delimited field, not a loose `42.*heartbeat`: the ISO
# timestamp contains `42` for one minute in sixty, so the loose pattern passed
# even when the issue number was wrong.
assert "ticks reference the issue number" \
  'grep -q "$(printf "\t42\theartbeat")" "$PROGRESS"'
kill -TERM "$PID"
# `RC=0; ... || RC=$?` — a bare `wait; RC=$?` aborts under `set -e` before the
# assignment, so the assertion below could only ever pass.
RC=0; wait "$PID" 2>/dev/null || RC=$?
PID=""
assert "clean TERM shutdown exits 0" '[ "$RC" -eq 0 ]'
assert "final line marks heartbeat stopped" 'tail -1 "$PROGRESS" | grep -qE "heartbeat.*stopped"'

echo "=== arg validation ==="
RC=0; run_bounded 5 bash "$HELPER" || RC=$?
assert "missing args -> usage, exit 1" '[ "$RC" -eq 1 ]'

# Paths stay inside the sandbox: /tmp/does-not-matter is world-writable, can be
# pre-created as a symlink by another user, and collides across parallel runs.
RC=0; run_bounded 5 bash "$HELPER" abc "$H/unused" || RC=$?
assert "non-numeric issue -> exit 2" '[ "$RC" -eq 2 ]'

RC=0; run_bounded 5 bash "$HELPER" 1 "$H/unused" --interval abc || RC=$?
assert "non-numeric interval -> exit 2" '[ "$RC" -eq 2 ]'

print_summary_and_exit
