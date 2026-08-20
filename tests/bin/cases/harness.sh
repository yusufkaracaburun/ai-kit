#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== harness ==="
# The harness decides whether every other case passes, so its own behaviour
# needs asserting. Two properties, pulling opposite ways: an assertion must
# not fail for a reason it never tested, and it must still fail when the
# thing it tests is false.

echo "=== sigpipe ==="
# `cmd | grep -q x` makes grep exit on the first match and SIGPIPE the
# writer. Under `pipefail` that 141 became the pipeline's status, so the
# assertion failed over the writer's death rather than the output's content.
# Whether it fired depended on payload size against the pipe buffer, which is
# why it read as flakiness: `recommend` and `structure` failed one CI run and
# passed a re-run of the identical commit.
#
# The sleep makes it deterministic rather than a race — grep has certainly
# matched and exited before the second write, so that write always lands on a
# closed pipe. Without the fix this assertion fails; with it, it passes.
assert "a writer SIGPIPEd by an early-exiting reader does not fail the assert" \
  '{ printf "MATCH\n"; sleep 0.3; printf "trailing\n"; } | grep -q MATCH'

# The suite has hundreds of `echo "$VAR" | grep -q` pipelines, so the fix
# lives in assert() rather than at the call sites. Guard the shape too: a
# large payload with the match at the front is the everyday version of the
# same race.
BIG="MATCH_ME$(printf 'x%.0s' $(seq 1 200000))"
assert "a large payload with an early match does not fail the assert" \
  'echo "$BIG" | grep -q MATCH_ME'

echo "=== signal-preserved ==="
# Suppressing pipefail must not suppress real failures. Run these through a
# sub-harness: they are expected to fail, and counting them here would make
# this case fail on purpose.
SUB="$(mktemp -d)"
cat > "$SUB/case.sh" <<SUBCASE
#!/usr/bin/env bash
set -euo pipefail
source "$AIKIT/tests/bin/lib/harness.sh"
assert "absent string" 'printf "MATCH\n" | grep -q ABSENT'
assert "false expression" '[ 1 -eq 2 ]'
assert "failing command" 'false'
print_summary_and_exit
SUBCASE
SUB_OUT="$(bash "$SUB/case.sh" 2>&1 || true)"
bash "$SUB/case.sh" >/dev/null 2>&1 && SUB_RC=0 || SUB_RC=$?
rm -rf "$SUB"

assert "a genuinely absent string still fails" 'echo "$SUB_OUT" | grep -q "FAIL: absent string"'
assert "a false expression still fails" 'echo "$SUB_OUT" | grep -q "FAIL: false expression"'
assert "a failing command still fails" 'echo "$SUB_OUT" | grep -q "FAIL: failing command"'
assert "a case with failures exits non-zero" '[ "$SUB_RC" -ne 0 ]'

echo "=== shell-state ==="
# assert() toggles pipefail around the evaluation, so it has to put it back —
# a case that sets `set -euo pipefail` must still have it afterwards.
#
# Sampled out here rather than inside an assert: within the evaluation
# pipefail is deliberately off, so asserting on it directly would always
# report off and say nothing about whether it was restored.
PF_AFTER=off
[ -o pipefail ] && PF_AFTER=on
assert "pipefail is restored after an assert" '[ "$PF_AFTER" = on ]'

print_summary_and_exit
