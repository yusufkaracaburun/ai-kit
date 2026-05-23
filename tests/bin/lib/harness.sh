#!/usr/bin/env bash
# Shared harness for tests/bin/cases/*.sh — provides assert(), PASS/FAIL
# counters, and exit-status convention. Each case file sources this then
# runs its asserts. run-all.sh dispatches cases in parallel.
#
# Convention:
#   - $AIKIT — repo root, set by the case file before sourcing.
#   - assert "<desc>" '<test-expression>'
#   - case file ends with: print_summary_and_exit
#
# A single FAIL → case exits 1. run-all.sh aggregates exit codes.

PASS=0
FAIL=0
FAIL_DETAILS=()

assert() {
  if eval "$2"; then
    echo "  OK: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
    FAIL_DETAILS+=("$1")
  fi
}

print_summary_and_exit() {
  echo ""
  if [ "$FAIL" -eq 0 ]; then
    echo "PASS: $PASS"
    exit 0
  else
    echo "FAIL: $FAIL passed: $PASS"
    for d in "${FAIL_DETAILS[@]}"; do
      echo "  - $d"
    done
    exit 1
  fi
}
