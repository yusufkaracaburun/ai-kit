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

echo "=== peer-sessions-check: protocol read from the rule ==="
# section: peer-sessions-protocol
FIRST_BULLET="$(grep -m1 '^- ' "$RULE")"
assert "injected context carries the rule's bullets" 'grep -qF -- "$FIRST_BULLET" <<<"$OUT"'
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

echo "=== plugin delivery: hooks.json + plugin-shaped layout ==="
# section: peer-sessions-plugin
# Peers are machine-wide, so the hook ships in the plugin's own manifest —
# a project that never ran /ai:setup still gets the nudge.
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "hooks.json registers the hook on SessionStart" \
  'python3 -c "
import json
d = json.load(open(\"$HOOKS_JSON\"))
cmds = [h[\"command\"] for b in d[\"hooks\"][\"SessionStart\"] for h in b[\"hooks\"]]
assert \"\${CLAUDE_PLUGIN_ROOT}/hooks/peer-sessions-check.sh\" in cmds, cmds
"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'

# ${CLAUDE_PLUGIN_ROOT} layout: hooks/, bin/ and standards/ are siblings.
TMP_P=$(mktemp -d)
mkdir -p "$TMP_P/hooks" "$TMP_P/bin"
cp "$HOOK" "$TMP_P/hooks/"
cp "$CLAIM" "$TMP_P/bin/"
OUT=$(fire "$OWN" "$TMP_P/hooks/peer-sessions-check.sh")
assert "plugin layout resolves bin/ai-kit-claim.sh and fires" 'grep -q "planny-7f" <<<"$OUT"'
assert "rule file missing -> peers table without the protocol block" '! grep -q "Protocol" <<<"$OUT"'
mkdir -p "$TMP_P/standards/rules"
cp "$RULE" "$TMP_P/standards/rules/"
OUT=$(fire "$OWN" "$TMP_P/hooks/peer-sessions-check.sh")
assert "plugin layout reads standards/rules beside hooks/" 'grep -qF -- "$FIRST_BULLET" <<<"$OUT"'
rm -rf "$TMP_P"

echo "=== ai-kit-claim: hardening ==="
# section: claim-hardening
registry "$PPID" peer-1 "" /x/planny
OUT_SHOW=$("$CLAIM" --session own-1 show)
ROW=$(grep "^| peer-1 |" <<<"$OUT_SHOW" || true)
assert "registry entry without a name falls back to the sid prefix" '[ -n "$ROW" ]'
assert "empty registry field keeps every column in place" '[ "$(awk -F"|" "{print NF}" <<<"$ROW")" -eq 9 ]'

"$CLAIM" --session '../../evil' set role=lead >/dev/null
assert "session id with / is sanitised into the claims dir" '[ -f "$CLAIMS/______evil.md" ] && [ ! -e "$TMP_H/.config/evil.md" ]'
"$CLAIM" --session '../../evil' release
assert "sanitised release removes the same file" '[ ! -f "$CLAIMS/______evil.md" ]'

ENVF="$TMP_H/env"
CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" <<<'{"session_id":"x;touch /tmp/pwn","cwd":"'"$REPO"'"}' >/dev/null
assert "hook sanitises session_id before writing CLAUDE_ENV_FILE" 'grep -qx "export AI_KIT_SESSION_ID=x_touch__tmp_pwn" "$ENVF"'
rm -f "$CLAIMS/x_touch__tmp_pwn.md"

"$CLAIM" --session own-1 set owns="lib/a, lib/b" >/dev/null
"$CLAIM" --session own-1 set owns= >/dev/null
assert "set key= clears the key" '! grep -q "^owns:" "$CLAIMS/own-1.md"'

rm -rf "$REG"
"$CLAIM" --session own-1 prune
assert "prune with the registry absent leaves claims untouched" '[ -f "$CLAIMS/own-1.md" ]'

rm -rf "$TMP_H"
print_summary_and_exit
