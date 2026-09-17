#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/peer-sessions-check.sh"
CLAIM="$AIKIT/bin/ai-kit-claim.sh"
RULE="$AIKIT/standards/rules/session-coordination.mini.md"

# Everything runs against a throwaway HOME: Claude Code's own session
# registry (~/.claude/sessions/<pid>.json) and the ai-kit claims dir are both
# faked there, so the real machine's peers never leak into an assertion.
TMP_H=$(mktemp -d)
export HOME="$TMP_H"
REG="$TMP_H/.claude/sessions"
CLAIMS="$TMP_H/.config/ai-kit/claims"
mkdir -p "$REG"

REPO="$TMP_H/planny-app-mobile"
mkdir -p "$REPO"
git -C "$REPO" init -q -b feat/home-skeleton

# A pid that is certainly dead: spawn, reap, reuse.
sleep 0.01 &
DEAD_PID=$!
wait "$DEAD_PID"
LIVE_PID=$$

registry() {
  # registry <pid> <session_id> <name> <cwd>
  printf '{"pid":%s,"sessionId":"%s","cwd":"%s","name":"%s","status":"idle","updatedAt":%s000}\n' \
    "$1" "$2" "$4" "$3" "$(date +%s)" > "$REG/$1.json"
}

fire() {
  # fire <payload> [hook] -> prints additionalContext, empty if silent
  bash "${2:-$HOOK}" <<<"$1" |
    python3 -c 'import json,sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null || true
}
OWN='{"session_id":"own-1","cwd":"'"$REPO"'","hook_event_name":"SessionStart","source":"startup"}'

echo "=== peer-sessions-check: solo is silent ==="
# section: peer-sessions-solo
registry "$LIVE_PID" own-1 ai-kit-99 "$REPO"
OUT=$(fire "$OWN")
assert "only own session live -> silent" '[ -z "$OUT" ]'
assert "skeleton claim written for own session" '[ -f "$CLAIMS/own-1.md" ]'
assert "skeleton records repo" 'grep -q "^repo: planny-app-mobile$" "$CLAIMS/own-1.md"'
assert "skeleton records branch" 'grep -q "^branch: feat/home-skeleton$" "$CLAIMS/own-1.md"'

echo "=== peer-sessions-check: live peer fires ==="
# section: peer-sessions-fires
registry 99999999 peer-dead planny-old /x/planny
OUT=$(fire "$OWN")
assert "peer with dead pid -> silent" '[ -z "$OUT" ]'

registry "$PPID" peer-1 planny-7f /x/planny
OUT=$(fire "$OWN")
assert "live peer -> fires" '[ -n "$OUT" ]'
assert "table names the peer" 'grep -q "planny-7f" <<<"$OUT"'
assert "table names the peer repo" 'grep -q "| planny |" <<<"$OUT"'
assert "own session not listed as a peer" '! grep -q "ai-kit-99" <<<"$OUT"'
assert "nudge asks for ListAgents + claim" 'grep -q "ListAgents" <<<"$OUT" && grep -q "ai-kit-claim.sh" <<<"$OUT"'
assert "emits valid JSON" 'bash "$HOOK" <<<"$OWN" | python3 -c "import json,sys; json.load(sys.stdin)"'

echo "=== peer-sessions-check: protocol inlined verbatim from the rule ==="
# section: peer-sessions-protocol
# The hook cannot read standards/ once copied into a project, so it carries
# the bullets itself. Pin them to the rule so the two cannot drift apart.
RULE_OK=1
while IFS= read -r line; do
  grep -qF -- "$line" "$HOOK" || RULE_OK=0
done < <(grep '^- ' "$RULE")
assert "every rule bullet appears in the hook" '[ "$RULE_OK" -eq 1 ]'
assert "rule body is ≤14 lines" '[ "$(awk "f; /^---$/ && NR>1 {f=1}" "$RULE" | grep -c .)" -le 14 ]'

echo "=== peer-sessions-check: stale claims pruned ==="
# section: peer-sessions-prune
printf -- '---\nrole: lead\nupdated: 2026-01-01T00:00:00Z\n---\n' > "$CLAIMS/gone-1.md"
fire "$OWN" >/dev/null
assert "claim without a live session is pruned" '[ ! -f "$CLAIMS/gone-1.md" ]'
assert "live peer claim survives" '[ -f "$CLAIMS/own-1.md" ]'

echo "=== peer-sessions-check: malformed input ==="
# section: peer-sessions-malformed
set +e
OUT_BAD=$(bash "$HOOK" <<<"not json" 2>&1); BAD_RC=$?
OUT_EMPTY=$(bash "$HOOK" </dev/null 2>&1); EMPTY_RC=$?
OUT_NOSID=$(bash "$HOOK" <<<'{"cwd":"/x"}' 2>&1); NOSID_RC=$?
set -e
assert "garbage payload exits 0 silent" '[ "$BAD_RC" -eq 0 ] && [ -z "$OUT_BAD" ]'
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$OUT_EMPTY" ]'
assert "payload without session_id exits 0 silent" '[ "$NOSID_RC" -eq 0 ] && [ -z "$OUT_NOSID" ]'

echo "=== ai-kit-claim: set / show / release round-trip ==="
# section: claim-roundtrip
"$CLAIM" --session own-1 set role=lead owns="lib/home/*, .pen:Q501VT" depends_on=planny >/dev/null
assert "set writes role" 'grep -q "^role: lead$" "$CLAIMS/own-1.md"'
assert "set writes owns as a list" 'grep -q "^owns: \[lib/home/\*, .pen:Q501VT\]$" "$CLAIMS/own-1.md"'
assert "set keeps skeleton fields" 'grep -q "^repo: planny-app-mobile$" "$CLAIMS/own-1.md"'
assert "set refreshes updated" 'grep -q "^updated: 20" "$CLAIMS/own-1.md"'

OUT_SHOW=$("$CLAIM" --session peer-1 show)
assert "show lists the other live session with its claim" 'grep -q "ai-kit-99.*| lead |.*Q501VT.*| planny |" <<<"$OUT_SHOW"'
assert "show omits the asking session" '! grep -q "planny-7f" <<<"$OUT_SHOW"'
OUT_ENV=$(AI_KIT_SESSION_ID=peer-1 "$CLAIM" show)
assert "AI_KIT_SESSION_ID identifies the session too" '[ "$OUT_ENV" = "$OUT_SHOW" ]'

set +e
"$CLAIM" --session own-1 set role=boss >/dev/null 2>&1; ROLE_RC=$?
"$CLAIM" --session own-1 set colour=red >/dev/null 2>&1; KEY_RC=$?
"$CLAIM" set role=lead >/dev/null 2>&1; NOSESSION_RC=$?
set -e
assert "unknown role rejected" '[ "$ROLE_RC" -ne 0 ]'
assert "unknown key rejected" '[ "$KEY_RC" -ne 0 ]'
assert "set without a session id rejected" '[ "$NOSESSION_RC" -ne 0 ]'

"$CLAIM" --session own-1 release
assert "release deletes the claim" '[ ! -f "$CLAIMS/own-1.md" ]'
"$CLAIM" --session own-1 release
assert "release is idempotent" '[ ! -f "$CLAIMS/own-1.md" ]'

echo "=== apply-peer-sessions-hook ==="
# section: apply-peer-sessions-hook
TMP_A=$(mktemp -d)
"$AIKIT/bin/apply-peer-sessions-hook.sh" "$TMP_A" >/dev/null
assert "hook copied + executable" '[ -x "$TMP_A/.claude/hooks/peer-sessions-check.sh" ]'
assert "claim helper copied next to it" '[ -x "$TMP_A/.claude/hooks/ai-kit-claim.sh" ]'
assert "SessionStart wired" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
ss = d[\"hooks\"][\"SessionStart\"]
assert len(ss) == 1, ss
assert ss[0][\"hooks\"][0][\"command\"].endswith(\"/.claude/hooks/peer-sessions-check.sh\"), ss
"'
"$AIKIT/bin/apply-peer-sessions-hook.sh" "$TMP_A" >/dev/null
assert "idempotent: second run does not stack" \
  'python3 -c "
import json
d = json.load(open(\"$TMP_A/.claude/settings.json\"))
assert len(d[\"hooks\"][\"SessionStart\"]) == 1
"'
OUT=$(fire "$OWN" "$TMP_A/.claude/hooks/peer-sessions-check.sh")
assert "copied hook finds the copied helper and still fires" 'grep -q "planny-7f" <<<"$OUT"'
rm -rf "$TMP_A"

echo "=== write-setup-marker records the branch ==="
# section: peer-sessions-marker
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --peer-sessions-hook=wired >/dev/null
assert "marker records peer_sessions_hook" \
  'python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"branches\"][\"peer_sessions_hook\"])" "$TMP_M/.ai-kit-setup" | grep -q wired'
rm -rf "$TMP_M"

rm -rf "$TMP_H"
print_summary_and_exit
