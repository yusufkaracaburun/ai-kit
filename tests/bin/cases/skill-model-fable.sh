#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== skill-model-fable ==="

# Spec-prep and debugging skills switch the turn to Fable; the lead stays on the session default.
for s in grill-with-docs grill-me to-issues to-prd diagnose; do
  f="$AIKIT/workflow/skills/$s/SKILL.md"
  assert "$s pins model: fable" "awk 'NR==1 && /^---\$/{fm=1; next} fm && /^---\$/{exit} fm' '$f' | grep -qx 'model: fable'"
done

print_summary_and_exit
