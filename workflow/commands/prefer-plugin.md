---
description: Toggle the machine-wide "prefer plugin install for Claude Code commands" opt-out — when ON, only /ai:<cmd> is available (no bare /doctor)
argument-hint: "on | off | status"
allowed-tools: Bash
---

Toggle the prefer-plugin marker. When ON, `install-global.sh` stops linking `workflow/commands/*.md` into `~/.claude/commands/` — commands are then only available via `/plugin install ai@yusufkaracaburun` under the `/ai:` namespace. Cursor command symlinks are unaffected.

!`bash "${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}/bin/ai-kit-prefer-plugin.sh" $ARGUMENTS`

Confirm the new state and remind the user that:
- Existing `~/.claude/commands/*.md` symlinks are **not** auto-removed when turning the marker on. Print the cleanup snippet from the tool output.
- They still need to install the plugin via `/plugin marketplace add yusufkaracaburun/marketplace` then `/plugin install ai@yusufkaracaburun` for `/ai:<cmd>` to become available.
