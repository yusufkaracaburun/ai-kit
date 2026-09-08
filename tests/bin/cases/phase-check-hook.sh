#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/phase-check.sh"

# The hook must fire on work-start prompts and stay silent on everything else.
# Firing on questions and exploration would tax every turn of a session for a
# nudge that only means something when work is about to start — so the fire /
# quiet split is what these cases pin down.
fire() {
  # fire <prompt> -> prints additionalContext, empty if silent
  python3 -c 'import json,sys; print(json.dumps({"prompt": sys.argv[1]}))' "$1" |
    bash "$HOOK" |
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
  "deploy naar staging"
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
  "!git status"
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

echo "=== apply-phase-check-hook ==="
# section: apply-phase-check-hook
TMP_A=$(mktemp -d)

"$AIKIT/bin/apply-phase-check-hook.sh" "$TMP_A" >/dev/null
assert "hook script copied into project" '[ -x "$TMP_A/.claude/hooks/phase-check.sh" ]'
assert "settings.json wires UserPromptSubmit" \
  'python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d[\"hooks\"][\"UserPromptSubmit\"][0][\"hooks\"][0][\"command\"])" "$TMP_A/.claude/settings.json" | grep -q "CLAUDE_PROJECT_DIR"'

# Idempotent: a second apply must not stack a second entry.
"$AIKIT/bin/apply-phase-check-hook.sh" "$TMP_A" >/dev/null
COUNT=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d["hooks"]["UserPromptSubmit"]))' "$TMP_A/.claude/settings.json")
assert "re-apply does not stack" '[ "$COUNT" -eq 1 ]'

# Non-destructive: unrelated keys and hooks survive the merge.
TMP_B=$(mktemp -d)
mkdir -p "$TMP_B/.claude"
cat > "$TMP_B/.claude/settings.json" <<'JSON'
{
  "env": {"FOO": "bar"},
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "other.sh"}]}]
  }
}
JSON
"$AIKIT/bin/apply-phase-check-hook.sh" "$TMP_B" >/dev/null
assert "unrelated env key survives" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"env\"][\"FOO\"])" "$TMP_B/.claude/settings.json" | grep -q bar'
assert "unrelated PreToolUse hook survives" \
  'grep -q "other.sh" "$TMP_B/.claude/settings.json"'

rm -rf "$TMP_A" "$TMP_B"

echo "=== write-setup-marker records the branch ==="
# section: phase-check-marker
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --phase-check-hook=wired >/dev/null
assert "marker records phase_check_hook" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"branches\"][\"phase_check_hook\"])" "$TMP_M/.ai-kit-setup" | grep -q wired'
rm -rf "$TMP_M"

print_summary_and_exit
