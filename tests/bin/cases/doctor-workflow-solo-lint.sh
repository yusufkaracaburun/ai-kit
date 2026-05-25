#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== doctor-workflow-solo-lint ==="
# Section: doctor-workflow-solo-lint
# ai-kit issue #70 (parent #52). /ai:doctor must lint workflow/skills/**/*.md
# + workflow/commands/**/*.md for team-size 'solo' / 'single dev' tokens and
# emit yellow DRIFT per hit, excluding install-layout `setup_mode=solo-*`
# vocabulary. Lint baselines at zero hits today; any future reintroduction
# surfaces.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

assert "doctor script exists" '[ -f "$DOCTOR" ]'

# Static checks — the lint exists in doctor.
assert "doctor has Workflow text drift section" \
  'grep -qE "Workflow text drift|workflow.*solo lint" "$DOCTOR"'
assert "doctor lint scans workflow/skills/**/*.md" \
  'grep -qE "workflow/skills" "$DOCTOR"'
assert "doctor lint scans workflow/commands/**/*.md" \
  'grep -qE "workflow/commands" "$DOCTOR"'
assert "doctor lint excludes setup_mode= lines" \
  'grep -qE "setup_mode" "$DOCTOR"'
assert "doctor lint references parent #52 in its message" \
  'grep -qE "issue #52|ai-kit #52|#52" "$DOCTOR"'

# Behaviour — baseline run from inside this ai-kit repo must be drift-free.
set +e
OUT_BASELINE="$(bash "$DOCTOR" "$AIKIT" 2>&1)"
EXIT_BASELINE=$?
set -e
assert "baseline (current workflow/): no workflow-text drift fires" \
  '! echo "$OUT_BASELINE" | grep -qE "Workflow text drift.*solo|workflow text drift.*single dev|workflow/skills/.*\\bsolo\\b|workflow/commands/.*\\bsolo\\b"'
assert "baseline doctor exit never raises to 2 (error)" '[ "$EXIT_BASELINE" -ne 2 ]'

# Behaviour — plant a violation in a sandbox ai-kit copy and verify the lint
# fires AND the setup_mode= line in the sandbox stays silent.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SANDBOX="$TMP/aikit"
mkdir -p "$SANDBOX/workflow/skills/foo" \
         "$SANDBOX/workflow/commands" \
         "$SANDBOX/bin/lib"
# Minimum ai-kit shell that the doctor invocation can resolve.
cp "$AIKIT/VERSION" "$SANDBOX/VERSION"
cp -R "$AIKIT/bin/lib" "$SANDBOX/bin/"
cp "$AIKIT/bin/ai-kit-doctor.sh" "$SANDBOX/bin/ai-kit-doctor.sh"
chmod +x "$SANDBOX/bin/ai-kit-doctor.sh"
# Planted violation:
cat > "$SANDBOX/workflow/skills/foo/SKILL.md" <<'PLANT'
---
name: foo
description: test fixture
---
This skill is for the single dev who works alone.
PLANT
# Whitelisted install-layout line — should NOT trigger lint:
cat > "$SANDBOX/workflow/skills/foo/INSTALL.md" <<'OK'
The mode `setup_mode=solo-both` describes install layout, not team size.
OK
set +e
OUT_PLANTED="$(bash "$SANDBOX/bin/ai-kit-doctor.sh" "$SANDBOX" 2>&1)"
set -e
assert "planted 'single dev' in workflow/ triggers lint DRIFT" \
  'echo "$OUT_PLANTED" | grep -qE "single dev|single-dev"'
assert "whitelisted setup_mode=solo-both stays silent (no drift)" \
  '! echo "$OUT_PLANTED" | grep -qiE "INSTALL\.md.*solo-both"'

print_summary_and_exit
