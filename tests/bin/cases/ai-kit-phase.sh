#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ai-kit-phase.sh reads/writes the "lifecycle" field of a project's
# .ai-kit-setup marker. It never touches $HOME, so no sandboxing is needed —
# every case operates on a throwaway --project directory.

phase() {
  # phase <project-path> [args...]
  local project="$1"; shift
  bash "$AIKIT/bin/ai-kit-phase.sh" --project "$project" "$@"
}

echo "=== missing marker ==="
T=$(mktemp -d)
RC=0; ERR=$(phase "$T" 2>&1) || RC=$?
assert "missing .ai-kit-setup -> exit 2" '[ "$RC" -eq 2 ]'
assert "error tells the user to run /ai:setup" 'grep -q "run /ai:setup first" <<<"$ERR"'
rm -rf "$T"

echo "=== read / write ==="
T=$(mktemp -d)
echo '{"branches": {}}' > "$T/.ai-kit-setup"
OUT=$(phase "$T")
assert "defaults to production when lifecycle is unset" '[ "$OUT" = "production" ]'

OUT=$(phase "$T" development)
assert "write reports the transition" 'grep -q "production → development" <<<"$OUT"'
OUT=$(phase "$T")
assert "read reflects the write" '[ "$OUT" = "development" ]'

echo "=== arg validation ==="
RC=0; phase "/no/such/dir" 2>/dev/null || RC=$?
assert "nonexistent project dir -> exit 2" '[ "$RC" -eq 2 ]'

RC=0; phase "$T" bogus 2>/dev/null || RC=$?
assert "unrecognized phase arg -> exit 1" '[ "$RC" -eq 1 ]'
rm -rf "$T"

print_summary_and_exit
