#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

CORE="$AIKIT/workflow/skills/audit-architecture/SKILL.md"
CORE_PLUGIN="$AIKIT/workflow/skills/audit-architecture/SKILL.md"

echo "=== core-skill-extension-wiring ==="
assert "core SKILL.md exists" '[ -f "$CORE" ]'

# Deferral sentence must be gone — extensions are no longer deferred.
assert "deferral sentence removed" \
  '! grep -q "Per-stack tuning extensions are deferred" "$CORE"'

# Step 3 must invoke the extension loader.
assert "step 3 calls audit-extension-loader.sh" \
  'grep -q "audit-extension-loader.sh" "$CORE"'

# Step 4 must mention invoking matched extensions via Skill tool.
assert "step 4 mentions extension invocation via Skill tool" \
  'grep -qE "invoke (each |matched |the )?extension.*Skill tool|Skill tool.*extension" "$CORE"'

# Step 6 must specify the merge rule with [stack] prefix.
assert "step 6 specifies [stack] tag prefix on merged findings" \
  'grep -qE "\[<?stack>?\][\` ].*(tag prefix|prefix)|prefix.*\[<?stack>?\]" "$CORE"'

# Report header must specify Extensions loaded: + Tools ingested: lines.
assert "report header lists Extensions loaded:" \
  'grep -q "Extensions loaded:" "$CORE"'
assert "report header lists Tools ingested:" \
  'grep -q "Tools ingested:" "$CORE"'

# Contract spec must be cross-linked from the core skill.
assert "core SKILL.md links to extension contract spec" \
  'grep -q "audit-architecture-extension.contract.md" "$CORE"'

# AI_KIT_AUDIT_NO_EXTEND env var must be documented in the skill itself.
assert "core SKILL.md documents AI_KIT_AUDIT_NO_EXTEND env var" \
  'grep -q "AI_KIT_AUDIT_NO_EXTEND" "$CORE"'

print_summary_and_exit
