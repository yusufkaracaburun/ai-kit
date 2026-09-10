#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== verify-setup recognises secrets_scan marker (#124) ==="

TMP=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both"}\n}\n' > "$TMP/.ai-kit-setup"
OUT="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP" 2>&1 || true)"
assert "flags missing secrets_scan key" 'grep -q "FAIL: secrets_scan recorded" <<<"$OUT"'
rm -rf "$TMP"

TMP2=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both", "secrets_scan": "clean"}\n}\n' > "$TMP2/.ai-kit-setup"
OUT2="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP2" 2>&1 || true)"
assert "recognises secrets_scan=clean" '! grep -q "FAIL: secrets_scan recorded" <<<"$OUT2"'
rm -rf "$TMP2"

print_summary_and_exit
