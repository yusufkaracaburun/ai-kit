#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== /ai:which keeps free text out of the shell ==="
# section: which-command

# Pre-execution evals $ARGUMENTS unquoted: a `?` aborts under zsh and `;` runs code.
HITS="$(grep -nE '!`[^`]*\$ARGUMENTS' "$AIKIT/workflow/commands/which.md" || true)"
assert "which.md does not pre-execute \$ARGUMENTS" '[ -z "$HITS" ]'

INTENT="can you review this? it's done; \$(exit 3)"
OUT="$(AI_KIT_ROOT="$AIKIT" "$AIKIT/bin/ai-kit-which.sh" "$INTENT" || true)"
assert "which: intent with ? ; ' stays literal" 'echo "$OUT" | grep -qxF "Intent: $INTENT"'
assert "which: intent with ? ; ' still routes" 'echo "$OUT" | grep -q "^1\. /ai:review"'

print_summary_and_exit
