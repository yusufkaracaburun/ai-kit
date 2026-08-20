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
    _assert_context "$2"
    FAIL=$((FAIL + 1))
    FAIL_DETAILS+=("$1")
  fi
}

# Print what the failed expression was looking at.
#
# Without this a failure gives the assertion's name and nothing else, which is
# fine when you can reproduce it and useless when you cannot. `doctor: opt-out
# alone exits 0` failed one CI run and passed a re-run of the same commit; all
# the log said was that the number was wrong, while the captured doctor output
# — the answer — sat in a variable and was discarded. By the time anyone
# looked, the runner was gone. Intermittent failures are exactly the ones that
# have to be diagnosable from the log alone.
#
# Two sources, both free. Every variable the expression names, and for an exit
# code the output that came with it: this suite pairs `FOO_EXIT` with
# `OUT_FOO` or `FOO_OUT` about half the time, and an exit code on its own
# rarely says why.
_assert_context() {
  local __expr="$1" __n __val __sib
  local __seen=" "

  for __n in $(printf '%s' "$__expr" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | tr -d '${' | sort -u); do
    case "$__seen" in *" $__n "*) continue ;; esac
    __seen="$__seen$__n "
    [ -n "${!__n+x}" ] || continue
    _assert_show "$__n" "${!__n}"

    # An exit code alone rarely says why. Pull in its output sibling.
    case "$__n" in
      *_EXIT | *_RC)
        local __stem="${__n%_EXIT}"
        __stem="${__stem%_RC}"
        for __sib in "OUT_$__stem" "${__stem}_OUT"; do
          case "$__seen" in *" $__sib "*) continue ;; esac
          [ -n "${!__sib+x}" ] || continue
          __seen="$__seen$__sib "
          _assert_show "$__sib" "${!__sib}"
        done
        ;;
    esac
  done
  return 0
}

# Bounded: a captured command's output can run to thousands of lines, and a
# log nobody scrolls through is the problem this exists to solve.
_assert_show() {
  local __name="$1" __val="$2" __lines
  if [ -z "$__val" ]; then
    echo "        $__name = (empty)"
    return
  fi
  __lines="$(printf '%s\n' "$__val" | wc -l | tr -d ' ')"
  if [ "$__lines" -le 1 ] && [ "${#__val}" -le 120 ]; then
    echo "        $__name = $__val"
  else
    echo "        $__name ($__lines lines):"
    printf '%s\n' "$__val" | head -12 | sed 's/^/          | /'
    if [ "$__lines" -gt 12 ]; then
      echo "          | … $(( __lines - 12 )) more"
      # The line that explains a failure is rarely in the first twelve. In
      # doctor's output the header and the clean checks come first and the one
      # `warn` that made it exit non-zero sat on line 16 of 34 — the cap hid
      # the answer and the log had to be re-fetched by hand. Pull anything
      # that looks like a verdict out of the tail.
      local __rest
      __rest="$(printf '%s\n' "$__val" | tail -n +13 | grep -iE '^[[:space:]]*(warn|err|error|fail)' | head -5)"
      if [ -n "$__rest" ]; then
        echo "          | ── from the truncated part:"
        printf '%s\n' "$__rest" | sed 's/^/          | /'
      fi
    fi
  fi
  # Never let diagnostics decide the run: a bare `[ … ] && echo` as the last
  # command returns 1 when false, and under `set -e` in the case that turns a
  # reported failure into an aborted file.
  return 0
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
