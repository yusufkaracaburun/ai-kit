#!/usr/bin/env bash
# Parallel test runner for tests/bin/cases/*.sh.
#
# Each case file is self-contained: sources lib/harness.sh, runs its asserts,
# and exits with PASS:N / FAIL:N. This runner dispatches them in parallel
# (xargs -P), aggregates pass counts, and surfaces failure detail.
#
# Usage:
#   ./tests/bin/run-all.sh            # parallel, JOBS=4 (default)
#   JOBS=8 ./tests/bin/run-all.sh     # tune parallelism
#   ./tests/bin/run-all.sh --serial   # one at a time (debug)
#
set -euo pipefail

AIKIT="$(cd "$(dirname "$0")/../.." && pwd)"
CASES="$AIKIT/tests/bin/cases"
JOBS="${JOBS:-4}"

if [ "${1:-}" = "--serial" ]; then
  JOBS=1
fi

if [ ! -d "$CASES" ]; then
  echo "No cases dir at $CASES" >&2
  exit 1
fi

TMPDIR_RUN=$(mktemp -d)
# shellcheck disable=SC2064  # Want $TMPDIR_RUN expanded now (the dir we just created), not later.
trap "rm -rf '$TMPDIR_RUN'" EXIT

START=$(date +%s)

# Run each case → capture stdout+stderr per file → write to temp.
# Exit code per case lives in <name>.rc; output in <name>.log.
# Hand-rolled job-pool (portable: avoids GNU parallel + xargs quoting woes).
run_case() {
  local case_file="$1"
  local case_name
  case_name="$(basename "$case_file" .sh)"
  local log="$TMPDIR_RUN/${case_name}.log"
  local rc_file="$TMPDIR_RUN/${case_name}.rc"
  if bash "$case_file" > "$log" 2>&1; then
    echo 0 > "$rc_file"
  else
    echo $? > "$rc_file"
  fi
}

CASE_FILES=()
while IFS= read -r f; do CASE_FILES+=("$f"); done < <(find "$CASES" -maxdepth 1 -name '*.sh' -type f | sort)

# All-at-once fan-out. Case count is small (≤ ~12) so an explicit pool isn't
# worth the bash 3.2 portability cost (macOS lacks `wait -n`).
PIDS=()
for case_file in "${CASE_FILES[@]}"; do
  run_case "$case_file" &
  PIDS+=($!)
done
for pid in "${PIDS[@]}"; do wait "$pid" || true; done

END=$(date +%s)
ELAPSED=$((END - START))

# Aggregate.
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_CASES=()

for log in "$TMPDIR_RUN"/*.log; do
  name=$(basename "$log" .log)
  rc=$(cat "${log%.log}.rc")
  pass_line=$(grep -E '^(PASS|FAIL):' "$log" | tail -1 || true)
  pass=$(echo "$pass_line" | grep -oE 'PASS: [0-9]+' | awk '{print $2}' || true)
  fail=$(echo "$pass_line" | grep -oE 'FAIL: [0-9]+' | awk '{print $2}' || true)
  pass="${pass:-0}"
  fail="${fail:-0}"
  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
  if [ "$rc" != "0" ]; then
    FAILED_CASES+=("$name")
    printf '✗ %s (rc=%s pass=%s fail=%s)\n' "$name" "$rc" "$pass" "$fail"
  else
    printf '✓ %s (pass=%s)\n' "$name" "$pass"
  fi
done

echo ""
echo "Total: $TOTAL_PASS passed, $TOTAL_FAIL failed — ${ELAPSED}s wall (JOBS=$JOBS)"

if [ "${#FAILED_CASES[@]}" -gt 0 ]; then
  echo ""
  echo "Failing cases — full output:"
  for c in "${FAILED_CASES[@]}"; do
    echo ""
    echo "--- $c ---"
    cat "$TMPDIR_RUN/$c.log"
  done
  exit 1
fi
exit 0
