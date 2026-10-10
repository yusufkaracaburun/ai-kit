#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #205: the four advisory hooks ship in the plugin's hooks.json, gated on the
# marker. A copy left in .claude/hooks/ by an older /ai:setup fires next to the
# plugin's and never gets fixes, so doctor names it and points at /ai:upgrade.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== no project copies ==="
A="$TMP/all"
mkdir -p "$A/.claude"
OUT_A="$(bash "$DOCTOR" "$A" --project-only 2>&1 || true)"
assert "no hook warning without project copies" \
  '! echo "$OUT_A" | grep -E "^  warn" | grep -q "hook"'

echo "=== stale project copies ==="
ST="$TMP/stale"
mkdir -p "$ST/.claude/hooks"
for s in search-delegation-check build-delegation-check phase-check context-drift-check; do
  echo '#!/usr/bin/env bash' > "$ST/.claude/hooks/$s.sh"
done
OUT_ST="$(bash "$DOCTOR" "$ST" --project-only 2>&1 || true)"
for n in search-delegation-check build-delegation-check phase-check context-drift-check; do
  assert "stale $n copy warned with the upgrade recipe" \
    'echo "$OUT_ST" | grep -qE "^  warn .*stale project copy of $n hook, run /ai:upgrade"'
done

echo "=== stale ~/.config/ai-kit/root ==="
RH="$TMP/home-stale"
mkdir -p "$RH/.config/ai-kit"
echo "$RH/gone/1.0.0" > "$RH/.config/ai-kit/root"
OUT_RH="$(HOME="$RH" bash "$DOCTOR" "$TMP/all" --project-only 2>&1 || true)"
assert "stale root file is warned with the plugin-current recipe" \
  'echo "$OUT_RH" | grep -E "^  warn .*config/ai-kit/root points at .*gone/1.0.0 \(missing\)" | grep -q "plugin-current"'

echo "=== no path argument: cwd is the project ==="
OUT_CWD="$(cd "$TMP/all" && bash "$DOCTOR" --project-only 2>&1 || true)"
assert "doctor run from a project cwd without a path still checks the project" \
  'echo "$OUT_CWD" | grep -q "^Project: .*all"'

print_summary_and_exit
