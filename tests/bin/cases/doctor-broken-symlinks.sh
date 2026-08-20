#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== doctor-broken-symlinks ==="
# doctor scans every directory ai-kit writes into — */skills (bootstrap
# symlinks) and */rules (emit-rules output) — and names the dead target of
# each broken link it finds. A third-party tool moving its own layout
# (Laravel Boost, .ai/ → .agents/) kills links bootstrap-project.sh never
# touches, so the remedy has to fit the link instead of blaming an ai-kit
# move. Dead links in directories ai-kit does not own warn, never error.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

P="$TMP/proj"
mkdir -p "$P/.claude/skills" "$P/.agents/skills" "$P/.cursor/skills" \
  "$P/.claude/rules" "$P/.cursor/rules" "$P/.junie" "$P/.agents/guidelines"

# The survivor: Boost moved .ai/guidelines/ to .agents/guidelines/, so
# global.md still exists — one directory over.
echo "global rule" > "$P/.agents/guidelines/global.md"
echo "engineering rule" > "$P/.claude/rules/kept.md"

ln -s "../../.ai/guidelines/global.md" "$P/.claude/rules/global.md"
ln -s "../../.ai/guidelines/engineering.md" "$P/.cursor/rules/engineering.md"
ln -s "../.ai/guidelines/global.md" "$P/.junie/global.md"
ln -s "$TMP/gone/tdd" "$P/.claude/skills/tdd"

OUT="$(bash "$DOCTOR" "$P" 2>&1 || true)"
set +e
bash "$DOCTOR" "$P" >/dev/null 2>&1
RC=$?
set -e

echo "=== rules directories are scanned ==="
assert ".claude/rules broken symlink reported" \
  'echo "$OUT" | grep -qE "^  ERR .*\.claude/rules — 1 broken symlink"'
assert ".cursor/rules broken symlink reported" \
  'echo "$OUT" | grep -qE "^  ERR .*\.cursor/rules — 1 broken symlink"'
assert ".claude/skills broken symlink still reported" \
  'echo "$OUT" | grep -qE "^  ERR .*\.claude/skills — 1 broken symlink"'
assert "broken symlink in an owned dir is an error (exit 2)" '[ "$RC" -eq 2 ]'

echo "=== each dead link names its target ==="
assert "link and dead target printed for .claude/rules" \
  'echo "$OUT" | grep -F -q ".claude/rules/global.md -> ../../.ai/guidelines/global.md"'
assert "link and dead target printed for .cursor/rules" \
  'echo "$OUT" | grep -F -q ".cursor/rules/engineering.md -> ../../.ai/guidelines/engineering.md"'

echo "=== the remedy fits the case ==="
assert "surviving target elsewhere → ln -sfn repoint recipe" \
  'echo "$OUT" | grep -F -q "ln -sfn \"$P/.agents/guidelines/global.md\" \"$P/.claude/rules/global.md\""'
assert "target gone entirely → removal recipe" \
  'echo "$OUT" | grep -F -q "rm -f \"$P/.cursor/rules/engineering.md\""'
assert "no repoint recipe offered for a target that is gone" \
  '! echo "$OUT" | grep -F "engineering.md" | grep -q "ln -sfn"'
assert "broken symlinks are not blamed on an ai-kit move" \
  '! echo "$OUT" | grep -q "ai-kit moved"'
assert "bootstrap-project.sh is not offered as the fix for a dead link" \
  '! echo "$OUT" | grep "broken symlink" | grep -q "bootstrap-project.sh"'

echo "=== directories ai-kit does not own ==="
assert ".junie dead link surfaces" \
  'echo "$OUT" | grep -F -q ".junie/global.md -> ../.ai/guidelines/global.md"'
assert ".junie dead link warns, never errors" \
  '! echo "$OUT" | grep -E "^  ERR" | grep -q "junie"'
assert "unowned sweep counts its findings in a warn line" \
  'echo "$OUT" | grep -qE "^  warn .*1 broken symlink"'

echo "=== clean project ==="
C="$TMP/clean"
mkdir -p "$C/.claude/skills" "$C/.agents/skills" "$C/.cursor/skills" \
  "$C/.claude/rules" "$C/.junie"
echo "rule" > "$C/.claude/rules/global.md"
echo "guideline" > "$C/.junie/guidelines.md"
ln -s "$AIKIT/workflow/skills" "$C/.claude/skills/all"
OUT_C="$(bash "$DOCTOR" "$C" 2>&1 || true)"
assert "clean project reports no broken symlinks" \
  '! echo "$OUT_C" | grep -q "broken symlink"'
assert "rules dir holding regular files resolves" \
  'echo "$OUT_C" | grep -qE "\.claude/rules — 1 entries resolve"'

echo "=== project without emitted rules ==="
N="$TMP/norules"
mkdir -p "$N/.claude/skills" "$N/.agents/skills" "$N/.cursor/skills"
ln -s "$AIKIT/workflow/skills" "$N/.claude/skills/all"
OUT_N="$(bash "$DOCTOR" "$N" 2>&1 || true)"
assert "absent rules dir is not reported (--no-rules is legitimate)" \
  '! echo "$OUT_N" | grep -q "rules absent"'

print_summary_and_exit
