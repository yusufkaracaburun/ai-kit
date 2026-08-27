#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# Regression tests for #145 — three ways the tooling misreported state.
#
# The common thread: each bug produced output that LOOKED healthy. A crashed
# case counted as zero instead of as a failure; a live worktree branch was
# offered for deletion; a linked worktree was called "not a git repo". None of
# them threw — they just quietly said something untrue.

echo "=== run-all: a case that dies before its summary counts as a failure ==="

# Build a throwaway cases dir with one healthy case and one that dies under
# `set -e` before reaching print_summary_and_exit. Point run-all.sh at it.
TMP_SUITE="$(mktemp -d)"
trap 'rm -rf "$TMP_SUITE"' EXIT
mkdir -p "$TMP_SUITE/cases"

cat > "$TMP_SUITE/cases/healthy.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
AIKIT="$AIKIT"
source "\$AIKIT/tests/bin/lib/harness.sh"
assert "healthy passes" 'true'
print_summary_and_exit
EOF

cat > "$TMP_SUITE/cases/crasher.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
AIKIT="$AIKIT"
source "\$AIKIT/tests/bin/lib/harness.sh"
assert "crasher's one real assertion" 'true'
false
print_summary_and_exit
EOF
chmod +x "$TMP_SUITE/cases/"*.sh

RUN_OUT="$(CASES="$TMP_SUITE/cases" bash "$AIKIT/tests/bin/run-all.sh" 2>&1)" || true

assert "the crashing case is listed with ✗" \
  'echo "$RUN_OUT" | grep -q "✗ crasher"'
assert "the total reports a failure, not '0 failed'" \
  '! echo "$RUN_OUT" | grep -qE "^Total: [0-9]+ passed, 0 failed"'
assert "the total counts the crash as exactly one failure" \
  'echo "$RUN_OUT" | grep -qE "^Total: [0-9]+ passed, 1 failed"'
assert "the healthy case still contributes its pass" \
  'echo "$RUN_OUT" | grep -qE "^Total: [1-9][0-9]* passed"'
assert "the crash is called out by name on stderr" \
  'echo "$RUN_OUT" | grep -q "crasher produced no PASS:/FAIL: line"'

echo "=== finished-work: a branch live in a worktree is not a cleanup candidate ==="

TMP_REPO="$(mktemp -d)"
git -C "$TMP_REPO" init -q .
git -C "$TMP_REPO" config user.email test@example.invalid
git -C "$TMP_REPO" config user.name "Test"
echo seed > "$TMP_REPO/seed.txt"
git -C "$TMP_REPO" add -A
git -C "$TMP_REPO" commit -qm "seed"
# A merged branch that is NOT checked out anywhere — a genuine candidate.
git -C "$TMP_REPO" branch stale-merged
# A merged branch that IS checked out in a linked worktree — live work.
git -C "$TMP_REPO" branch live-in-worktree
git -C "$TMP_REPO" worktree add -q "$TMP_REPO/wt" live-in-worktree

FW_OUT="$(bash "$AIKIT/bin/ai-kit-docs-sync-finished-work.sh" "$TMP_REPO" 2>&1)" || true

assert "a merged branch with no worktree is still reported" \
  'echo "$FW_OUT" | grep -q "stale-merged"'
assert "a branch checked out in a linked worktree is NOT reported" \
  '! echo "$FW_OUT" | grep -q "live-in-worktree"'
assert "git's + marker never leaks into a reported branch name" \
  '! echo "$FW_OUT" | grep -qE "^\+ |[[:space:]]\+ [a-z]"'

git -C "$TMP_REPO" worktree remove --force "$TMP_REPO/wt" 2>/dev/null || true
rm -rf "$TMP_REPO"

echo "=== release.sh: a linked worktree is a git repo ==="

# `.git` is a FILE in a linked worktree, so `[ -d .git ]` reported "not a git
# repo" and blocked the release path there.
assert "release.sh does not gate on .git being a directory" \
  '! grep -q "\[ ! -d \\".git\\" \]" "$AIKIT/bin/release.sh"'
assert "release.sh uses git rev-parse to detect a repo" \
  'grep -q "git rev-parse --git-dir" "$AIKIT/bin/release.sh"'

print_summary_and_exit
