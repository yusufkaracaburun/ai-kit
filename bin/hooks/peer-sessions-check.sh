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
# protocol (the session-coordination rule, inlined: this file is copied into
# projects and cannot read standards/), and the instruction to call
# `ListAgents` once and register a claim. Without peers: nothing, so a solo
# session pays zero context for this.
#
# Silent by design — a hook must never break a session. Missing registry,
# malformed payload, helper not found: exit 0, no output.
#
# Wire it up with bin/apply-peer-sessions-hook.sh, or by hand:
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/peer-sessions-check.sh"
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
cwd="$(read_field '.cwd')"
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# Two layouts: copied into a project (.claude/hooks/, helper alongside) or
# run from source (bin/hooks/, helper one dir up).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || true)"
claim=""
for cand in "$HOOK_DIR/ai-kit-claim.sh" "$HOOK_DIR/../ai-kit-claim.sh"; do
  [ -x "$cand" ] && { claim="$(cd "$(dirname "$cand")" && pwd)/ai-kit-claim.sh"; break; }
done
[ -n "$claim" ] || exit 0

export AI_KIT_SESSION_ID="$sid"
"$claim" prune >/dev/null 2>&1 || true
branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)"
"$claim" set repo="$(basename "$cwd")" cwd="$cwd" ${branch:+branch="$branch"} >/dev/null 2>&1 || true
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export AI_KIT_SESSION_ID=$sid" >> "$CLAUDE_ENV_FILE" 2>/dev/null

peers="$("$claim" show 2>/dev/null || true)"
[ -n "$peers" ] || exit 0

# Verbatim copy of the bullets in standards/rules/session-coordination.mini.md
# — tests/bin/cases/peer-sessions-hook.sh pins the two together. `read`, not
# `$(cat <<EOF)`: bash 3.2 (macOS /bin/bash) cannot parse the apostrophes in
# a heredoc nested inside a command substitution.
read -r -d '' protocol <<'EOF' || true
- Register a claim at start and refresh it when your scope changes: `ai-kit-claim.sh set role=<lead|build|design|e2e|review> owns=<paths, .pen frames, devices> provides=<api version, release> depends_on=<repos, resources>`.
- One lead per repo, named by the user. The lead owns push/merge order; non-leads commit locally and report to the lead. No lead named → the first session on the repo is lead and says so in its claim.
- "Who owns X" is a file read, not a broadcast: `ai-kit-claim.sh show`. Before editing a path, .pen frame or device a peer claims, message the owner first and wait for a reply.
- Message a peer only on: (1) same repo with branch/file overlap; (2) your work touches something the peer claims as a dependency (kit release, API contract, deploy); (3) a shared-resource clash (emulator, device, port, DB, .pen frame); (4) relaying a user decision that affects the peer's claimed area. Anything else: read, don't send.
- Relay a user decision verbatim and attributed — "From <user>, via <me>: …" — never paraphrased as your own.
- Keep the index empty around a peer's announced commit: stage per path, read the staged diff, commit — never leave a partial stage in a shared tree.
- Release your claim when done: `ai-kit-claim.sh release`.
EOF

ctx="ai-kit peer sessions: other Claude Code sessions are live on this machine. Coordinate — do not re-negotiate.

$peers

Protocol (session-coordination rule):
$protocol

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
