#!/usr/bin/env bash
# Claude Code SessionStart hook: keep ~/.claude/rules/ai-kit pointing at the
# plugin's rules/ payload (ADR-0015). The host loads ~/.claude/rules/**/*.md
# natively in every project — pathless files at session start, `paths:`
# files on touch — so every universal always-on rule reaches every session with no
# per-repo copies. The plugin cache path carries the version
# (.../ai/1.94.0/rules), so every /plugin update moves the target; this hook
# re-points the link on the first session after, one `ln -sfn`, nothing
# else. That first session still ran on the old link (the host reads rules
# before hooks report back) — one-session lag, then correct.
#
# Opt-out, machine-wide: bin/ai-kit-no-global-rules.sh on
#
# Silent by design — a hook must never break a session. No rules dir
# found, link already current, a real directory in the way (the user's
# own): exit 0, no output. /ai:doctor reports the link state.
#
# Wired via workflow/hooks/hooks.json (plugin install). Source layout, by
# hand in .claude/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{
#           "type": "command",
#           "command": "${CLAUDE_PROJECT_DIR}/bin/hooks/global-rules-link.sh"
#         }]
#       }]
#     }
#   }

set -uo pipefail

[ -t 0 ] || cat >/dev/null 2>&1 || true   # drain the session payload; unused
[ -f "${HOME:-}/.config/ai-kit/no-global-rules" ] && exit 0

# Two layouts: plugin (hooks/ + rules/ side by side) or source (bin/hooks/ +
# workflow/rules/).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || true)"
rules=""
for cand in "$HOOK_DIR/../rules" "$HOOK_DIR/../../workflow/rules"; do
  [ -d "$cand" ] && { rules="$(cd "$cand" && pwd)"; break; }
done
[ -n "$rules" ] || exit 0

link="${HOME:-}/.claude/rules/ai-kit"
[ -e "$link" ] && [ ! -L "$link" ] && exit 0            # user's own directory — never clobber
[ "$(readlink "$link" 2>/dev/null)" = "$rules" ] && exit 0
mkdir -p "${HOME:-}/.claude/rules" 2>/dev/null && ln -sfn "$rules" "$link" 2>/dev/null
exit 0
