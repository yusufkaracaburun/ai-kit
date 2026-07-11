#!/usr/bin/env bash
# Claude Code PreToolUse hook: keep wide codebase sweeps out of the main context.
#
# Raw search output is the single biggest source of context bloat. The
# context-discipline rule already says "delegate wide exploration to a
# sub-agent" — but a rule is prose an agent skips under pressure. This hook
# puts the same instruction where the agent cannot miss it: at the moment it
# reaches for a repo-wide search.
#
# Fires on WIDE sweeps only — never on a narrow lookup:
#
#   Bash  — command contains grep / rg / ripgrep / find / fd / ack / ag
#   Grep  — no `path` (or path is the project root) → searches the whole repo
#   Glob  — same
#
# A Grep scoped to a known directory does NOT fire. That distinction is what
# keeps this hook signal instead of noise: without it the nudge would inject
# on every one of the 20-30 Grep calls in a session and cost more context than
# it saves.
#
# Two messages, mutually exclusive:
#
#   1. graphify-out/graph.json present → point at `graphify query`, which
#      returns a scoped subgraph instead of raw matches.
#   2. Otherwise → point at a sub-agent (Explore / ai:explore, plus
#      cavecrew-investigator when the caveman plugin is enabled), so the raw
#      output lands in the sub-agent's context, not this one.
#
# Advisory only: emits additionalContext, never blocks, always exits 0.
#
# Wire it up with bin/apply-search-delegation-hook.sh, or by hand:
#
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Bash|Grep|Glob",
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/search-delegation-check.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# ---------------------------------------------------------------------------
# Parse the payload: which tool, and is this a wide sweep?
#
# Emits two null-delimited fields: tool_name, then "wide" or "narrow".
# ---------------------------------------------------------------------------
read_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r "$1 // empty" <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
keys = sys.argv[1].lstrip(".").split(".")
cur = d
for k in keys:
    if not isinstance(cur, dict):
        sys.exit(0)
    cur = cur.get(k)
    if cur is None:
        sys.exit(0)
print(cur if isinstance(cur, str) else "")' "$1" <<<"$payload" 2>/dev/null
  fi
}

tool="$(read_field '.tool_name')"
[ -z "$tool" ] && exit 0

wide=0
case "$tool" in
  Bash)
    cmd="$(read_field '.tool_input.command')"
    [ -z "$cmd" ] && exit 0
    case "$cmd" in
      *grep*|*"rg "*|*ripgrep*|*"find "*|*"fd "*|*"ack "*|*"ag "*) wide=1 ;;
    esac
    ;;
  Grep|Glob)
    # A wide sweep is one with no path narrowing. An explicit path means the
    # agent already knows where to look — that is exactly the behaviour we
    # want, so stay quiet.
    p="$(read_field '.tool_input.path')"
    p="${p%/}"
    if [ -z "$p" ] || [ "$p" = "." ] || [ "$p" = "$root" ]; then
      wide=1
    fi
    ;;
esac

[ "$wide" -eq 1 ] || exit 0

# ---------------------------------------------------------------------------
# Pick the message.
# ---------------------------------------------------------------------------
if [ -f "$root/graphify-out/graph.json" ]; then
  msg="graphify: knowledge graph at graphify-out/. For focused questions, run \`graphify query \"<question>\"\` (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context."
else
  agents="\`Explore\` or \`ai:explore\`"
  if [ -f "$HOME/.claude/settings.json" ] &&
     grep -q '"caveman@caveman"[[:space:]]*:[[:space:]]*true' "$HOME/.claude/settings.json" 2>/dev/null; then
    agents="\`Explore\`, \`ai:explore\`, or \`cavecrew-investigator\` — the last returns a compressed file:line table"
  fi
  msg="context-discipline: this is a repo-wide sweep. Raw search output is the biggest source of context bloat — delegate it to a sub-agent (${agents}) so the dump lands in the sub-agent's context and only the conclusion comes back here. Search inline only when you already know the file, or the answer is a single line."
fi

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$msg" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
else
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
