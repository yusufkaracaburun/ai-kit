#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ADR-0012 phase (c): write-setup-marker.sh always auto-computes and writes
# branches.global_channel_available — no flag, no caller involvement, it's
# a machine fact (does a global channel already serve ai-kit skills),
# not a per-project choice. Mocks $HOME so the result is deterministic
# regardless of the machine actually running this test suite.

echo "=== write-setup-marker auto-writes global_channel_available ==="

H1=$(mktemp -d)
TMP_M1=$(mktemp -d)
HOME="$H1" "$AIKIT/bin/write-setup-marker.sh" "$TMP_M1" --setup-mode=solo-both >/dev/null
assert "neither channel present -> false" \
  'grep -q "\"global_channel_available\": false" "$TMP_M1/.ai-kit-setup"'
rm -rf "$H1" "$TMP_M1"

H2=$(mktemp -d)
mkdir -p "$H2/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"
TMP_M2=$(mktemp -d)
HOME="$H2" "$AIKIT/bin/write-setup-marker.sh" "$TMP_M2" --setup-mode=solo-both >/dev/null
assert "plugin cache present -> true" \
  'grep -q "\"global_channel_available\": true" "$TMP_M2/.ai-kit-setup"'
rm -rf "$H2" "$TMP_M2"

print_summary_and_exit
