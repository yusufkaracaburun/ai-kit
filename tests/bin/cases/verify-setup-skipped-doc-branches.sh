#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== verify-setup skips domain.md when domain_docs was skipped; workflow.md stays bootstrap-owned ==="

TMP=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both", "setup_tier": "full", "domain_docs": "skipped", "workflow": "skipped"}\n}\n' > "$TMP/.ai-kit-setup"
OUT="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP" 2>&1 || true)"
assert "no domain.md FAIL when domain_docs skipped" '! grep -q "FAIL: domain.md" <<<"$OUT"'
assert "workflow.md still checked (bootstrap-owned)" 'grep -q "FAIL: workflow.md" <<<"$OUT"'
rm -rf "$TMP"

TMP2=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both", "setup_tier": "full"}\n}\n' > "$TMP2/.ai-kit-setup"
OUT2="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP2" 2>&1 || true)"
assert "still checks domain.md when the key is absent" 'grep -q "FAIL: domain.md" <<<"$OUT2"'
rm -rf "$TMP2"

TMP3=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both", "dev_environment": false}\n}\n' > "$TMP3/.ai-kit-setup"
OUT3="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP3" 2>&1 || true)"
assert "no dev-environment.md FAIL when dev_environment is false" '! grep -q "FAIL: dev-environment.md" <<<"$OUT3"'
assert "still checks dev-environment.md when the key is absent" 'grep -q "FAIL: dev-environment.md" <<<"$OUT2"'
rm -rf "$TMP3"

print_summary_and_exit
