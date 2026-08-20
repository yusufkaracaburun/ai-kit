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
  # An assertion asks what the output contains, not whether the process that
  # produced it survived writing. `echo "$BIG" | grep -q x` makes grep exit on
  # the first match, which SIGPIPEs the writer mid-stream; under `pipefail`
  # that 141 becomes the pipeline's status and the assertion fails for a
  # reason it was never testing. Whether the race fires depends on payload
  # size against the pipe buffer, so it surfaces as flakiness rather than a
  # clean failure — `recommend` and `structure` failed one CI run and passed
  # a re-run of the identical commit.
  #
  # Fixed here rather than at the call sites: the suite has 262 such
  # pipelines across 20 case files, and an earlier per-site fix
  # ("avoid SIGPIPE race in detect-tooling JSON asserts") left every other one
  # in place. Disabling pipefail for the evaluation makes the reader's verdict
  # the answer, which is what every one of these asserts means.
  local __pipefail=off
  [ -o pipefail ] && __pipefail=on
  set +o pipefail

  local __ok=0
  eval "$2" || __ok=1

  [ "$__pipefail" = on ] && set -o pipefail

  if [ "$__ok" -eq 0 ]; then
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
