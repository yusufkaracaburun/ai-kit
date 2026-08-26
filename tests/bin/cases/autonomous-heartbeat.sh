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
PROGRESS="$H/nested/dir/progress.txt"
bash "$HELPER" 42 "$PROGRESS" --interval 1 &
PID=$!
sleep 2.2
assert "progress dir auto-created" '[ -d "$(dirname "$PROGRESS")" ]'
assert "at least 2 brewing ticks logged" \
  '[ "$(grep -cE "heartbeat.*brewing" "$PROGRESS" 2>/dev/null || echo 0)" -ge 2 ]'
assert "ticks reference the issue number" 'grep -qE "42.*heartbeat" "$PROGRESS"'
kill -TERM "$PID"
wait "$PID" 2>/dev/null
RC=$?
assert "clean TERM shutdown exits 0" '[ "$RC" -eq 0 ]'
assert "final line marks heartbeat stopped" 'tail -1 "$PROGRESS" | grep -qE "heartbeat.*stopped"'
rm -rf "$H"

echo "=== arg validation ==="
RC=0; bash "$HELPER" 2>/dev/null || RC=$?
assert "missing args -> usage, exit 1" '[ "$RC" -eq 1 ]'

RC=0; bash "$HELPER" abc /tmp/does-not-matter 2>/dev/null || RC=$?
assert "non-numeric issue -> exit 2" '[ "$RC" -eq 2 ]'

RC=0; bash "$HELPER" 1 /tmp/does-not-matter --interval abc 2>/dev/null || RC=$?
assert "non-numeric interval -> exit 2" '[ "$RC" -eq 2 ]'

print_summary_and_exit
