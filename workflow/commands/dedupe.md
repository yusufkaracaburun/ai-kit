---
description: Scan for ai-kit duplication (personal skills/agents shadowing plugin, orphan emitted rules, hook overlap). Reports only — never deletes.
argument-hint: "[path] [--json] [--fix]"
allowed-tools: Bash
---

Run `ai-kit-dedupe.sh` against the current project and surface its findings.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-dedupe.sh" $ARGUMENTS`

Summarise the output for the user:

1. **Duplicates by surface** — list each `DUP` / `ORPHAN` entry plainly. Don't editorialise.
2. **Risk per duplicate** — single line, plain English:
   - `DUP skill` → personal version shadows plugin's; `/skill-name` resolves to the older personal copy. Plugin version available as `/ai:skill-name`.
   - `DUP agent` → personal `~/.claude/agents/<name>.md` shadows plugin's subagent definition.
   - `ORPHAN rule` → emitted rule in `.cursor/rules/` no longer exists in plugin (likely renamed/removed in a plugin update).
3. **Cleanup** — if the user passed `--fix`, the script already printed `rm` commands. Show them and **wait for the user to confirm** before executing. Never auto-run the suggested removals.
4. **All-clear** — single line: "No duplicates or orphans found."

For ORPHAN rules where the user wants the rule back, suggest re-running `/ai:recommend-rules` to re-emit the current canonical list.

Don't suggest deletes the script didn't surface, and don't extend cleanup beyond what was reported.
