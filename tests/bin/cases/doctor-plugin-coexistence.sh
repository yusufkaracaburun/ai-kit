#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ADR-0012: doctor's plugin-coexistence check read
# `~/.claude/plugins/marketplaces/ai-kit` — a path that has never existed
# since the v3.0 rename (ADR-0004) moved the plugin to `ai@yusufkaracaburun`.
# The marketplace dir is keyed by marketplace name, not plugin name; the
# correct "is the plugin installed" signal is the cache dir
# (`~/.claude/plugins/cache/yusufkaracaburun/ai`), which only exists once
# the plugin is actually installed.

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

# Simulate the plugin being installed: the cache dir exists.
mkdir -p "$H/.claude/plugins/cache/yusufkaracaburun/ai/1.0.0"

# Simulate a coexisting symlink-install pointing at this ai-kit clone.
mkdir -p "$H/.claude/skills"
ln -sfn "$AIKIT/workflow/skills/review" "$H/.claude/skills/review"

P="$H/proj"
mkdir -p "$P"

echo "=== doctor plugin-coexistence check uses the live marketplace path ==="
OUT="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" 2>&1 || true)"
assert "warns about plugin + symlink-install coexisting" \
  'echo "$OUT" | grep -q "both plugin (.*) and symlink-install (.*) active"'

rm -rf "$H/.claude/plugins/cache/yusufkaracaburun"
OUT_NOPLUGIN="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" "$P" 2>&1 || true)"
assert "no coexistence warning once the plugin cache is gone" \
  '! echo "$OUT_NOPLUGIN" | grep -q "both plugin (.*) and symlink-install (.*) active"'

print_summary_and_exit
