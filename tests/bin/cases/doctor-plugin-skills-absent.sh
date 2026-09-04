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

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

# A fake plugin-cache-shaped ai-kit root so doctor resolves itself as
# plugin-installed (same detection ai-kit-root.sh's sync_plugin_current_link
# already uses: */plugins/cache/* in the resolved root).
FAKE_ROOT="$H/plugins/cache/mkt/ai/1.0.0"
mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/workflow/skills" "$FAKE_ROOT/workflow/commands"
cp -R "$AIKIT/bin/." "$FAKE_ROOT/bin/"
ln -sfn "$AIKIT/context" "$FAKE_ROOT/context"

P="$H/proj"
mkdir -p "$P"

echo "=== doctor resolved via the plugin cache ==="
OUT="$(HOME="$H" bash "$FAKE_ROOT/bin/ai-kit-doctor.sh" "$P" --project-only 2>&1 || true)"
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

echo "=== doctor resolved from a dev clone (not a plugin) — unchanged ==="
OUT_DEV="$(bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" --project-only 2>&1 || true)"
assert ".claude/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.claude/skills absent (run bootstrap-project.sh)"'
assert ".agents/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.agents/skills absent (run bootstrap-project.sh)"'
assert ".cursor/skills absent still warns without a plugin install" \
  'echo "$OUT_DEV" | grep -q "\.cursor/skills absent (run bootstrap-project.sh)"'

print_summary_and_exit
