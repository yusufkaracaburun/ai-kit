#!/usr/bin/env bash
# Claude Code SessionStart hook: tell a session that peers exist, and how to
# coordinate with them.
#
# Sessions on this machine can already see and message each other
# (`ListAgents`, `SendMessage`) — but nothing told a new session that peers
# were there, so every "who owns X", every push rule and every deploy notice
# was re-negotiated per session, per day. This hook closes that gap at the
# moment it matters: session start.
#
# Peers come from Claude Code's own session registry,
# ~/.claude/sessions/<pid>.json — the data behind `ListAgents` (session id,
# name, cwd, status). A registry entry counts as live iff its pid answers
# `kill -0`; bin/ai-kit-claim.sh owns that lookup and the claims table, this
# hook only formats. Every run also writes a skeleton claim (repo, cwd,
# branch) for the current session, so a session that never registers is
# still visible to the others, and prunes claims whose session is gone.
#
# With peers: ONE additionalContext — the peers table, the coordination
# protocol (the bullets of standards/rules/session-coordination.mini.md,
# read at fire time so the rule has one home), and the instruction to call
# `ListAgents` once and register a claim. Without peers: nothing, so a solo
# session pays zero context for this.
#
# Silent by design — a hook must never break a session. Missing registry,
# malformed payload, helper not found: exit 0, no output. Rule file not
# found: peers table without the protocol block.
#
# Peers are machine-wide, so this ships in the plugin's own manifest
# (workflow/hooks/hooks.json) — every session gets it, no /ai:setup needed.
# Source layout, by hand in .claude/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/bin/hooks/peer-sessions-check.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

read_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r "$1 // empty" <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
v = d.get(sys.argv[1].lstrip(".")) if isinstance(d, dict) else None
print(v if isinstance(v, str) else "")' "$1" <<<"$payload" 2>/dev/null
  fi
}

sid="$(read_field '.session_id')"
[ -z "$sid" ] && exit 0
# Lands unquoted in CLAUDE_ENV_FILE and names the claim file; same charset
# ai-kit-claim.sh enforces so both resolve to the same claim.
sid="${sid//[^A-Za-z0-9_-]/_}"
cwd="$(read_field '.cwd')"
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# Two layouts, same fallback as session-rules-inject.sh: plugin
# (workflow/hooks/ + workflow/bin/ + workflow/standards/) or source
# (bin/hooks/ + bin/ + standards/).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || true)"
claim=""
for cand in "$HOOK_DIR/../bin/ai-kit-claim.sh" "$HOOK_DIR/../ai-kit-claim.sh"; do
  [ -x "$cand" ] && { claim="$(cd "$(dirname "$cand")" && pwd)/ai-kit-claim.sh"; break; }
done
[ -n "$claim" ] || exit 0
protocol=""
for cand in "$HOOK_DIR/../standards/rules/session-coordination.mini.md" \
            "$HOOK_DIR/../../standards/rules/session-coordination.mini.md"; do
  [ -f "$cand" ] && { protocol="$(sed -n '/^- /p' "$cand")"; break; }
done

export AI_KIT_SESSION_ID="$sid"
"$claim" prune >/dev/null 2>&1 || true
branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)"
"$claim" set repo="$(basename "$cwd")" cwd="$cwd" ${branch:+branch="$branch"} >/dev/null 2>&1 || true
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export AI_KIT_SESSION_ID=$sid" >> "$CLAUDE_ENV_FILE" 2>/dev/null

peers="$("$claim" show 2>/dev/null || true)"
[ -n "$peers" ] || exit 0

ctx="ai-kit peer sessions: other Claude Code sessions are live on this machine. Coordinate — do not re-negotiate.

$peers
${protocol:+
Protocol (session-coordination rule):
$protocol
}
Do now: call \`ListAgents\` once, then register with \`$claim set role=… owns=… depends_on=…\` (AI_KIT_SESSION_ID=$sid is exported for this session; your skeleton claim already records repo, cwd and branch)."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  esc="${ctx//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
