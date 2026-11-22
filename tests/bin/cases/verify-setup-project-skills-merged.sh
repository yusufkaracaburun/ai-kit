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

echo "=== retrofit marker: skip_skill_merge=true without project_skills_merged ==="
TMP4=$(mktemp -d)
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both", "skip_skill_merge": true}\n}\n' > "$TMP4/.ai-kit-setup"
OUT4="$(bash "$AIKIT/bin/verify-setup.sh" "$TMP4" --strict 2>&1 || true)"
assert "skip_skill_merge=true skips the project skills dirs" \
  '! grep -q "FAIL: .cursor/skills present" <<<"$OUT4"'
rm -rf "$TMP4"

echo "=== ai-kit-status reads the same fact ==="
TMP5=$(mktemp -d)
mkdir -p "$TMP5/home" "$TMP5/proj"
touch "$TMP5/proj/AGENTS.md"
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-global", "project_skills_merged": false, "dev_environment": false, "setup_tier": "minimal"}\n}\n' > "$TMP5/proj/.ai-kit-setup"
OUT5="$(HOME="$TMP5/home" bash "$AIKIT/bin/ai-kit-status.sh" "$TMP5/proj" 2>&1 || true)"
assert "solo-global without project skill dirs is a complete bootstrap" \
  'grep -q "^Bootstrap: complete" <<<"$OUT5"'
assert "solo-global does not list skill dirs as missing" \
  '! grep -q "missing: .*skills" <<<"$OUT5"'
printf '{\n  "ai_kit_version": "1.0.0",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both"}\n}\n' > "$TMP5/proj/.ai-kit-setup"
OUT6="$(HOME="$TMP5/home" bash "$AIKIT/bin/ai-kit-status.sh" "$TMP5/proj" 2>&1 || true)"
assert "solo-both still lists missing skill dirs" \
  'grep -q "missing: .*\.claude/skills" <<<"$OUT6"'
rm -rf "$TMP5"

print_summary_and_exit
