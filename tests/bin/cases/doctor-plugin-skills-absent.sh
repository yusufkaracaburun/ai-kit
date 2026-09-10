#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #114 §"Doctor makes it worse": when ai-kit is installed as a Claude Code
# plugin, .claude/skills and .agents/skills symlinks are pure duplication —
# the plugin already serves /ai:*. A project with none (emeq-hub, the
# "healthy reference config") should not be nagged to run bootstrap-project.sh
# for those two. .cursor/skills is unaffected: Cursor has no plugin channel,
# so its absence still warns regardless (caveat in the issue, deliberately
# left as-is).
#
# ADR-0012 phase (d): the signal is now global_channel_available — a
# machine fact read from $HOME — not "is this doctor invocation's own
# $AIKIT resolved via a plugin-cache path." $HOME must be mocked in both
# directions here, since the machine actually running this suite may or
# may not have the real plugin installed under its real $HOME.

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

P="$H/proj"
mkdir -p "$P"

echo "=== global channel available (plugin cache present under \$HOME) ==="
mkdir -p "$H/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"
OUT="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" --project-only 2>&1 || true)"
assert ".claude/skills absent is not warned (plugin serves it)" \
  '! echo "$OUT" | grep -q "\.claude/skills absent (run bootstrap-project.sh)"'
assert ".agents/skills absent is not warned (plugin serves it)" \
  '! echo "$OUT" | grep -q "\.agents/skills absent (run bootstrap-project.sh)"'
assert ".claude/skills absent surfaces as info instead" \
  'echo "$OUT" | grep -q "info  .claude/skills absent — served by the ai-kit plugin"'
assert ".agents/skills absent surfaces as info instead" \
  'echo "$OUT" | grep -q "info  .agents/skills absent — served by the ai-kit plugin"'
assert ".cursor/skills absent still warns (no plugin channel for Cursor)" \
  'echo "$OUT" | grep -q "\.cursor/skills absent (run bootstrap-project.sh)"'
rm -rf "$H/.claude/plugins/cache/yusufkaracaburun"

echo "=== no global channel available — unchanged ==="
OUT_DEV="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" --project-only 2>&1 || true)"
assert ".claude/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.claude/skills absent (run bootstrap-project.sh)"'
assert ".agents/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.agents/skills absent (run bootstrap-project.sh)"'
assert ".cursor/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.cursor/skills absent (run bootstrap-project.sh)"'

print_summary_and_exit
