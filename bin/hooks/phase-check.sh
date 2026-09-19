#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: name the ai-kit phase before building.
#
# The failure it closes: an agent reads a feature request and goes straight to
# plan + code, never touching the workflow the kit exists to provide — no
# check for an existing issue, no `tdd`, no `review`. The work lands correct
# and the process is skipped entirely, which is invisible until someone asks
# afterwards which skill ran.
#
# Why a hook and not only a rule. A pathless `.claude/rules/*.md` does load
# every session on Claude Code (#182), but only if the project emitted it —
# a plugin-served repo may carry no rules at all, and a rule read at session
# start is buried by the time the feature request arrives. This hook puts one
# fixed line in front of every prompt: no ranking, no word budget, no
# dependency on what a project happens to have emitted.
#
# Fires on work-start prompts only — a build/fix/ship verb in the prompt.
# Questions, explanations and exploration stay silent, and so does an
# explicit `/slash` command (the user already picked the phase) or a `!bash`
# passthrough.
#
# The skip list rides in the message rather than in the regex: a prompt is
# too short to tell "fix the typo" from "fix the auth bug" reliably, and a
# regex that tried would need endless maintenance. The agent applies it.
#
# Advisory only: emits additionalContext, never blocks, always exits 0.
#
# Wire it up with bin/apply-phase-check-hook.sh, or by hand:
#
#   {
#     "hooks": {
#       "UserPromptSubmit": [{
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/phase-check.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

read_prompt() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.prompt // empty' <<<"$payload" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
p = d.get("prompt") if isinstance(d, dict) else None
print(p if isinstance(p, str) else "")' <<<"$payload" 2>/dev/null
  fi
}

prompt="$(read_prompt)"
[ -z "$prompt" ] && exit 0

# Leading / or ! — the user named a command already; nothing to route.
case "$prompt" in
  /*|!*) exit 0 ;;
esac

# Work-start verbs, NL + EN. Word-bounded so `fix` does not match `prefix`.
VERBS='implementeer|implement|bouw|build|refactor|herschrijf|rewrite|maak|create|schrijf|write|fix|repareer|solve|deploy|release|ship|uitrollen'
PHRASES='voeg( .*)? toe|pak( .*)? op|los( .*)? op|start (met|on)|begin met|werk aan|work on'

printf '%s' "$prompt" \
  | grep -Eiq "(^|[^[:alnum:]])(${VERBS}|${PHRASES})([^[:alnum:]]|\$)" || exit 0

msg="ai-kit phase check: name the phase and the skill before you build — Ideation \`grill-with-docs\`, \`to-prd\`, \`prototype\` · Development \`to-issues\` → \`triage\` → \`tdd\` · Testing \`review\`, \`qa\`, \`diagnose\` · Deployment \`ship\` · Ops \`retro\`. Check \`/ai:next\` for an existing issue first. Unsure which skill → \`/ai:which\`. Skip for a typo, lint fix or version bump."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$msg" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
else
  esc="${msg//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
