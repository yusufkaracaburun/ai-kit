#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #113: a project that only updates the plugin gets new skills but never the
# hook a newer /ai:setup would have wired, and the marker keeps saying
# `wired`. Doctor derives the expected set from bin/apply-*-hook.sh and
# checks .claude/settings.json — the marker is advisory: its `wired` claim is
# verified against settings.json, its `skipped` is the user's recorded choice.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# wire_all <project> [skip-name] — run every applier the doctor derives from.
wire_all() {
  local p="$1" skip="${2:-}" a
  for a in "$AIKIT"/bin/apply-*-hook.sh; do
    [ "$a" = "$AIKIT/bin/apply-$skip-hook.sh" ] && continue
    bash "$a" "$p" >/dev/null
  done
}

echo "=== every expected hook registered ==="
A="$TMP/all"
mkdir -p "$A"
wire_all "$A"
OUT_A="$(bash "$DOCTOR" "$A" --project-only 2>&1 || true)"
assert "ok line names every hook" \
  'echo "$OUT_A" | grep -qE "^  ok .*hooks wired in .claude/settings.json: .*context-drift.*phase-check.*search-delegation"'
assert "no hook warning when all are wired" \
  '! echo "$OUT_A" | grep -E "^  warn" | grep -q "hook"'

echo "=== one hook missing ==="
M="$TMP/missing"
mkdir -p "$M"
wire_all "$M" context-drift
OUT_M="$(bash "$DOCTOR" "$M" --project-only 2>&1 || true)"
assert "missing hook warns, never errors" \
  'echo "$OUT_M" | grep -qE "^  warn .*hook context-drift not in .claude/settings.json"'
assert "warning carries the apply recipe" \
  'echo "$OUT_M" | grep -F -q "run: bash $AIKIT/bin/apply-context-drift-hook.sh $M"'
OK_M="$(echo "$OUT_M" | grep -E "^  ok .*hooks wired in .claude/settings.json:" || true)"
assert "wired hooks still reported ok, missing one left out" \
  'grep -q "phase-check" <<<"$OK_M" && grep -q "search-delegation" <<<"$OK_M" && ! grep -q "context-drift" <<<"$OK_M"'
assert "no disagreement claimed without a marker" \
  '! echo "$OUT_M" | grep -q "disagree"'

echo "=== marker says wired, settings.json lacks it ==="
D="$TMP/disagree"
mkdir -p "$D"
wire_all "$D" context-drift
bash "$AIKIT/bin/write-setup-marker.sh" "$D" --context-drift-hook=wired >/dev/null
OUT_D="$(bash "$DOCTOR" "$D" --project-only 2>&1 || true)"
assert "marker vs settings.json disagreement is named" \
  'echo "$OUT_D" | grep -qE "^  warn .*hook context-drift: .ai-kit-setup says wired but .claude/settings.json does not register .claude/hooks/context-drift-check.sh — marker and reality disagree"'
assert "disagreement warning carries the apply recipe" \
  'echo "$OUT_D" | grep -F -q "run: bash $AIKIT/bin/apply-context-drift-hook.sh $D"'

echo "=== marker says skipped ==="
S="$TMP/skipped"
mkdir -p "$S"
wire_all "$S" context-drift
bash "$AIKIT/bin/write-setup-marker.sh" "$S" --context-drift-hook=skipped >/dev/null
OUT_S="$(bash "$DOCTOR" "$S" --project-only 2>&1 || true)"
assert "skipped per marker is info, not warn" \
  'echo "$OUT_S" | grep -qE "^  info .*hook context-drift skipped per .ai-kit-setup"'
assert "no warn for a hook the user declined" \
  '! echo "$OUT_S" | grep -E "^  warn" | grep -q "context-drift"'

echo "=== no .claude/ dir (Cursor-only) ==="
C="$TMP/cursor"
mkdir -p "$C/.cursor/skills"
OUT_C="$(bash "$DOCTOR" "$C" --project-only 2>&1 || true)"
assert "hook check absent without .claude/" \
  '! echo "$OUT_C" | grep -qE "hook.*(wired|not in|skipped)"'

print_summary_and_exit
