#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"
# shellcheck source=../../../bin/lib/ai-kit-root.sh
source "$AIKIT/bin/lib/ai-kit-root.sh"

# ADR-0012 phase (b): `global_channel_available` is the read-only fact half
# of the setup_mode decomposition — does *some* global channel already
# serve ai-kit skills without this project's involvement (the plugin, or
# the legacy symlink-install)? No behavior changes yet; this only asserts
# the check itself is correct against each combination.

echo "=== global_channel_available ==="

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; global_channel_available" \
  && assert "neither channel: false" false \
  || assert "neither channel: false" true

mkdir -p "$H/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"
HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; global_channel_available" \
  && assert "plugin cache only: true" true \
  || assert "plugin cache only: true" false
rm -rf "$H/.claude/plugins/cache/yusufkaracaburun"

mkdir -p "$H/.config/ai-kit"
echo "/some/root" > "$H/.config/ai-kit/root"
HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; global_channel_available" \
  && assert "symlink-install root file only: true" true \
  || assert "symlink-install root file only: true" false

mkdir -p "$H/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"
HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; global_channel_available" \
  && assert "both channels: true" true \
  || assert "both channels: true" false

print_summary_and_exit
