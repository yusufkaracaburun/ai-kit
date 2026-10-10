#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/lead-nudge.sh"
LINE='Lead reply: open with Doing / Where / Needs-you (count) / Advice; the recommendation goes in the same turn as any question; invoke the phase skill, do not name it; after the first lookup, lookups go to an agent; briefs carry "Decisions in force".'

TMP_H=$(mktemp -d)
export HOME="$TMP_H"
bash "$AIKIT/bin/ai-kit-claim.sh" --session lead1 set role=lead >/dev/null
bash "$AIKIT/bin/ai-kit-claim.sh" --session build1 set role=build >/dev/null

fire() {
  # fire <session_id> <prompt> -> hook stdout
  python3 -c 'import json,sys; print(json.dumps({"session_id": sys.argv[1], "prompt": sys.argv[2]}))' "$1" "$2" |
    bash "$HOOK" 2>/dev/null || true
}

echo "=== lead-nudge: lead prompts ==="
# section: lead-nudge-fires
OUT=$(fire lead1 "wat is de status van de PR")
assert "lead + normal prompt prints the line" '[ "$OUT" = "$LINE" ]'
for p in "/ai:tdd" "!git status" "<cross-session-message from=\"p\">x</cross-session-message>" \
  "<agent-message from=\"b\">x</agent-message>" "<task-notification>x</task-notification>"; do
  OUT=$(fire lead1 "$p")
  assert "lead + skip prefix is silent: ${p:0:24}" '[ -z "$OUT" ]'
done

echo "=== lead-nudge: not lead ==="
# section: lead-nudge-silent
OUT=$(fire build1 "wat is de status")
assert "role=build is silent" '[ -z "$OUT" ]'
OUT=$(fire noclaim "wat is de status")
assert "no claim is silent" '[ -z "$OUT" ]'

echo "=== lead-nudge: failure safety ==="
# section: lead-nudge-safety
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1)
EMPTY_RC=$?
STUB="$TMP_H/stub"
mkdir -p "$STUB"
for t in bash cat awk; do ln -s "$(command -v "$t")" "$STUB/$t"; done
NOTOOL_OUT=$(PATH="$STUB" bash "$HOOK" <<<'{"session_id":"lead1","prompt":"hi"}' 2>&1)
NOTOOL_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
assert "no jq or python3 exits 0 silent" '[ "$NOTOOL_RC" -eq 0 ] && [ -z "$NOTOOL_OUT" ]'
rm -rf "$TMP_H"

echo "=== lead-nudge: plugin delivery ==="
# section: lead-nudge-plugin
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "hooks.json registers lead-nudge on UserPromptSubmit" \
  'python3 -c "
import json
d = json.load(open(\"$HOOKS_JSON\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"UserPromptSubmit\"] for h in b[\"hooks\"]]
assert \"\${CLAUDE_PLUGIN_ROOT}/hooks/lead-nudge.sh\" in cmds, cmds
"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'

print_summary_and_exit
