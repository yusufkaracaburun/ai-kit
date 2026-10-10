#!/usr/bin/env bash
# Claude Code SessionStart + SessionEnd hook: keep ~/.claude/rules/ai-kit pointing at the
# plugin's rules/ payload (ADR-0015). The host loads ~/.claude/rules/**/*.md
# natively in every project — pathless files at session start, `paths:`
# files on touch — so every universal always-on rule reaches every session with no
# per-repo copies. The target is the newest version dir in the plugin cache,
# not this script's own: at SessionEnd after a /plugin update the old plugin
# still runs, so re-pointing there lets the next session start on fresh rules.
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

# Two layouts: plugin (hooks/ + rules/ side by side) or source (workflow/bin/hooks/).
# pwd -P: source reaches this file via the root bin symlink (ADR-0016); `[ -d ]` resolves `..` physically, `cd` logically.
HOOK_DIR="$(cd "$(dirname "$0")" && pwd -P 2>/dev/null || true)"
cache="$(cd "$HOOK_DIR/../.." && pwd -P)"
newest="$(for d in "$cache"/*/rules; do v="${d%/rules}"; v="${v##*/}"; [[ -d $d && $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$v"; done | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
rules=""
[ -n "$newest" ] && rules="$(cd "$cache/$newest/rules" && pwd -P)"
[ -n "$rules" ] || for cand in "$HOOK_DIR/../rules" "$HOOK_DIR/../../rules"; do
  [ -d "$cand" ] && { rules="$(cd "$cand" && pwd -P)"; break; }
done
[ -n "$rules" ] || exit 0

link="${HOME:-}/.claude/rules/ai-kit"
[ -e "$link" ] && [ ! -L "$link" ] && exit 0            # user's own directory — never clobber
[ "$(readlink "$link" 2>/dev/null)" = "$rules" ] && exit 0
mkdir -p "${HOME:-}/.claude/rules" 2>/dev/null && ln -sfn "$rules" "$link" 2>/dev/null
exit 0
