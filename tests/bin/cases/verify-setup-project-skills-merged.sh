#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ADR-0012 phase (d): once a marker dual-writes branches.project_skills_merged,
# verify-setup.sh must prefer it over deriving from setup_mode — this is the
# combination that could not exist before phase (c) landed. verify-setup.sh
# only prints a line for a FAILING check ("FAIL: <name>"); a passing check
# is silent — so "skipped correctly" is asserted as the absence of the
# "present"-check failure, not the presence of an "OK" line.

echo "=== project_skills_merged=false wins even under project-only ==="
TMP1=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "project-only", "project_skills_merged": false}\n}\n' > "$TMP1/.ai-kit-setup"
OUT1="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP1" 2>&1 || true)"
assert "does not demand .claude/skills to exist" \
  '! grep -q "FAIL: .claude/skills present" <<<"$OUT1"'
rm -rf "$TMP1"

echo "=== project_skills_merged=true wins even under solo-global ==="
TMP2=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-global", "project_skills_merged": true}\n}\n' > "$TMP2/.ai-kit-setup"
OUT2="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP2" 2>&1 || true)"
assert "now requires .claude/skills to exist" \
  'grep -q "FAIL: .claude/skills present" <<<"$OUT2"'
rm -rf "$TMP2"

echo "=== legacy marker (no new field) is unaffected ==="
TMP3=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-global"}\n}\n' > "$TMP3/.ai-kit-setup"
OUT3="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP3" 2>&1 || true)"
assert "derives skipped from legacy solo-global, unchanged behavior" \
  '! grep -q "FAIL: .claude/skills present" <<<"$OUT3"'
rm -rf "$TMP3"

print_summary_and_exit
