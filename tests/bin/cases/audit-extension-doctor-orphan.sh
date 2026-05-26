#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== doctor-orphan-extension ==="
# Doctor must flag an audit-architecture-<stack>/ extension folder that exists
# without the core audit-architecture/ skill present. Sandbox: build a fake
# AI_KIT_ROOT with the orphan layout and point the doctor at it.

FAKE_ROOT=$(mktemp -d)
trap 'rm -rf "$FAKE_ROOT"' EXIT

# Mirror enough of the real ai-kit layout that ai-kit-doctor.sh runs.
cp -R "$AIKIT/bin" "$FAKE_ROOT/bin"
cp -R "$AIKIT/standards" "$FAKE_ROOT/standards"
cp -R "$AIKIT/context" "$FAKE_ROOT/context"
cp "$AIKIT/VERSION" "$FAKE_ROOT/VERSION"

# Orphan layout: extension folder present, core audit-architecture/ MISSING.
mkdir -p "$FAKE_ROOT/workflow/skills"
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-laravel"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-laravel/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-laravel
description: orphan extension — core missing
extends: audit-architecture
applies_to:
  frameworks: ["laravel"]
  languages: []
---
SKILL_EOF

set +e
AI_KIT_ROOT="$FAKE_ROOT" AI_KIT_SKIP_GLOBALS=1 bash "$FAKE_ROOT/bin/ai-kit-doctor.sh" --project-only > /tmp/doctor-orphan.out 2>&1
DOC_EXIT=$?
set -e

assert "doctor surfaces orphan extension warning" \
  'grep -qE "orphan.*audit-architecture-laravel|audit-architecture-laravel.*orphan" /tmp/doctor-orphan.out'

# Healthy layout: both core skill + extension present. Doctor must NOT warn.
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture
description: core skill present
---
SKILL_EOF

set +e
AI_KIT_ROOT="$FAKE_ROOT" AI_KIT_SKIP_GLOBALS=1 bash "$FAKE_ROOT/bin/ai-kit-doctor.sh" --project-only > /tmp/doctor-healthy.out 2>&1
HEALTH_EXIT=$?
set -e

assert "doctor does NOT warn when core skill present" \
  '! grep -qE "orphan.*audit-architecture-laravel" /tmp/doctor-healthy.out'

rm -f /tmp/doctor-orphan.out /tmp/doctor-healthy.out

print_summary_and_exit
