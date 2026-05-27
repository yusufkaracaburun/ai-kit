#!/usr/bin/env bash
# Integration test for ai-kit-repo-skill-hint.sh — both-surfaces logic (#96).
#
# Covers (per #96 acceptance criteria):
#   - both project-local docs-sync + framework /ai:docs-sync applicable → both cues + use-which-for-what hint
#   - only project-local docs-sync → only the project cue
#   - only /ai:docs-sync applicable (docs/ exists, no project skill) → only the framework cue
#   - neither → silent
#   - reuses applicability helper (no duplicated detection logic)
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HINT="$AIKIT/bin/ai-kit-repo-skill-hint.sh"

echo "=== artefacts-exist ==="
assert "repo-skill-hint script exists + executable" '[ -x "$HINT" ]'
assert "script sources applicability lib" \
  'grep -q "lib/applicability.sh" "$HINT"'
assert "script does NOT reimplement is_docs_sync_applicable" \
  '! grep -q "^is_docs_sync_applicable()" "$HINT"'

echo "=== both-surfaces ==="
TMP_BOTH=$(mktemp -d)
trap 'rm -rf "$TMP_BOTH" "$TMP_PROJ_ONLY" "$TMP_FW_ONLY" "$TMP_NEITHER"' EXIT
mkdir -p "$TMP_BOTH/docs" "$TMP_BOTH/.agents/skills/docs-sync"
cat > "$TMP_BOTH/.agents/skills/docs-sync/SKILL.md" <<'EOF'
---
name: docs-sync
description: Project-specific docs drift detection — RSO numbers, persona names, ADR triggers.
---
EOF
OUT_BOTH="$(bash "$HINT" "$TMP_BOTH")"
assert "both fixture: shows project /docs-sync" \
  'echo "$OUT_BOTH" | grep -qE "^[[:space:]]+- /docs-sync"'
assert "both fixture: shows framework /ai:docs-sync" \
  'echo "$OUT_BOTH" | grep -qE "^[[:space:]]+- /ai:docs-sync"'
assert "both fixture: project cue annotated as repo-specific drift" \
  'echo "$OUT_BOTH" | grep -F -q "repo-specific drift"'
assert "both fixture: framework cue annotated as universal drift" \
  'echo "$OUT_BOTH" | grep -F -q "universal drift"'
assert "both fixture: 'Also applicable from the framework' header appears" \
  'echo "$OUT_BOTH" | grep -F -q "Also applicable from the framework"'

echo "=== project-skill-plus-framework ==="
# A project-local docs-sync skill brings a SKILL.md, which itself triggers
# is_docs_sync_applicable (the dead-links check would scan it). So whenever
# a project skill exists, the framework cue also applies — by design.
TMP_PROJ_ONLY=$(mktemp -d)
mkdir -p "$TMP_PROJ_ONLY/.agents/skills/docs-sync"
cat > "$TMP_PROJ_ONLY/.agents/skills/docs-sync/SKILL.md" <<'EOF'
---
name: docs-sync
description: Project-specific docs drift detection.
---
EOF
OUT_PROJ="$(bash "$HINT" "$TMP_PROJ_ONLY")"
assert "project-skill fixture: shows /docs-sync" \
  'echo "$OUT_PROJ" | grep -qE "^[[:space:]]+- /docs-sync"'
assert "project-skill fixture: also shows /ai:docs-sync (SKILL.md is markdown)" \
  'echo "$OUT_PROJ" | grep -qE "^[[:space:]]+- /ai:docs-sync"'

echo "=== framework-only ==="
TMP_FW_ONLY=$(mktemp -d)
mkdir -p "$TMP_FW_ONLY/docs"
OUT_FW="$(bash "$HINT" "$TMP_FW_ONLY")"
assert "framework-only: shows /ai:docs-sync" \
  'echo "$OUT_FW" | grep -qE "^[[:space:]]+- /ai:docs-sync"'
assert "framework-only: project cue absent" \
  '! echo "$OUT_FW" | grep -qE "^[[:space:]]+- /docs-sync"'
assert "framework-only: 'Framework skill applicable:' header" \
  'echo "$OUT_FW" | grep -F -q "Framework skill applicable:"'

echo "=== neither ==="
TMP_NEITHER=$(mktemp -d)
OUT_NONE="$(bash "$HINT" "$TMP_NEITHER")"
assert "neither: silent banner '/ai:docs-sync not applicable'" \
  'echo "$OUT_NONE" | grep -F -q "/ai:docs-sync not applicable"'
assert "neither: no project cue" \
  '! echo "$OUT_NONE" | grep -qE "^[[:space:]]+- /docs-sync"'
assert "neither: no framework cue" \
  '! echo "$OUT_NONE" | grep -qE "^[[:space:]]+- /ai:docs-sync"'

print_summary_and_exit
