#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/phase-check.sh"
# Older markers carry no phase_check_hook field; the hook fires for them.
PROJ=$(mktemp -d)
echo '{"branches": {}}' > "$PROJ/.ai-kit-setup"

# The hook must fire on work-start prompts and stay silent on everything else.
# Firing on questions and exploration would tax every turn of a session for a
# nudge that only means something when work is about to start — so the fire /
# quiet split is what these cases pin down.
fire() {
  # fire <prompt> [project] -> prints additionalContext, empty if silent
  python3 -c 'import json,sys; print(json.dumps({"prompt": sys.argv[1]}))' "$1" |
    CLAUDE_PROJECT_DIR="${2:-$PROJ}" bash "$HOOK" |
    python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null || true
}

echo "=== phase-check: work-start prompts fire ==="
# section: phase-check-fires
for p in \
  "implementeer uren namens anderen achter een machtiging" \
  "pak dit issue op" \
  "fix de auth bug" \
  "voeg een kolom toe aan de migratie" \
  "los dit op" \
  "refactor the payment service" \
  "build the export endpoint" \
  "deploy naar staging" \
  "fix the login bug"
do
  OUT=$(fire "$p")
  assert "fires: $p" '[ -n "$OUT" ]'
done

echo "=== phase-check: non-work prompts stay silent ==="
# section: phase-check-silent
for p in \
  "wat doet deze functie?" \
  "leg uit hoe de router werkt" \
  "waar staat de config" \
  "hoeveel tests zijn er" \
  "prefix de key met env" \
  "address the review comments" \
  "/ai:tdd start" \
  "!git status" \
  "<cross-session-message from=\"peer\">fix the login bug</cross-session-message>" \
  "<agent-message from=\"builder\">fix the login bug</agent-message>" \
  "<task-notification>fix the login bug</task-notification>"
do
  OUT=$(fire "$p")
  assert "silent: $p" '[ -z "$OUT" ]'
done

echo "=== phase-check: message content ==="
# section: phase-check-message
OUT=$(fire "implementeer de nieuwe endpoint")
assert "names the phases" 'grep -q "Ideation" <<<"$OUT" && grep -q "Deployment" <<<"$OUT"'
assert "points at an existing issue first" 'grep -q "ai:next" <<<"$OUT"'
assert "carries the skip list" 'grep -qi "typo" <<<"$OUT"'

set +e
bash "$HOOK" </dev/null >/dev/null 2>&1
EMPTY_RC=$?
set -e
assert "empty payload exits clean" '[ "$EMPTY_RC" -eq 0 ]'

set +e
echo 'not json' | bash "$HOOK" >/dev/null 2>&1
JUNK_RC=$?
set -e
assert "malformed payload exits clean" '[ "$JUNK_RC" -eq 0 ]'

echo "=== phase-check: marker gate ==="
# section: phase-check-gate
NOMARK=$(mktemp -d)
OUT=$(fire "fix the login bug" "$NOMARK")
assert "silent without .ai-kit-setup" '[ -z "$OUT" ]'
SKIP=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$SKIP" --phase-check-hook=skipped >/dev/null
OUT=$(fire "fix the login bug" "$SKIP")
assert "silent when marker says skipped" '[ -z "$OUT" ]'

echo "=== phase-check: plugin delivery ==="
# section: phase-check-plugin
assert "hooks.json registers phase-check on UserPromptSubmit" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"UserPromptSubmit\"] for h in b[\"hooks\"]]
assert \"\${CLAUDE_PLUGIN_ROOT}/hooks/phase-check.sh\" in cmds, cmds
"'
rm -rf "$NOMARK" "$SKIP" "$PROJ"

echo "=== write-setup-marker records the branch ==="
# section: phase-check-marker
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --phase-check-hook=wired >/dev/null
assert "marker records phase_check_hook" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"branches\"][\"phase_check_hook\"])" "$TMP_M/.ai-kit-setup" | grep -q wired'
rm -rf "$TMP_M"

print_summary_and_exit
