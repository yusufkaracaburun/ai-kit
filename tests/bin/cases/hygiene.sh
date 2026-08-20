#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HYG="$AIKIT/bin/ai-kit-hygiene.sh"

echo "=== ai-kit-hygiene: score line always emitted ==="
# section: ai-kit-hygiene-score

# Skip every section → no penalties → score must be 100. Confirms the
# score line is unconditional (printed even on fully clean / fully skipped
# runs) — the user asked for "altijd de score vermelden".
OUT_CLEAN="$("$HYG" "$AIKIT" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean --skip-secrets-gate 2>&1)"
assert "hygiene prints Score: 100/100 on a fully-skipped run" 'echo "$OUT_CLEAN" | grep -q "^Score: 100/100$"'
assert "hygiene omits To reach 100 block when score == 100" '! echo "$OUT_CLEAN" | grep -q "^To reach 100:"'

# Real run against the ai-kit repo itself — score line must be present.
# Don't assert a specific number (depends on host state); just assert the
# format.
OUT_REAL="$("$HYG" "$AIKIT" 2>&1 || true)"
assert "hygiene prints a Score: N/100 line on a real run" 'echo "$OUT_REAL" | grep -qE "^Score: [0-9]+/100$"'

# When the score is below 100, the "To reach 100:" block must appear.
SCORE_LINE="$(echo "$OUT_REAL" | grep -E "^Score: [0-9]+/100$" | head -1)"
SCORE_NUM="$(echo "$SCORE_LINE" | sed -E 's@Score: ([0-9]+)/100@\1@')"
if [ "$SCORE_NUM" -lt 100 ]; then
  assert "hygiene shows To reach 100 recipe when score<100" 'echo "$OUT_REAL" | grep -q "^To reach 100:"'
fi

print_summary_and_exit
