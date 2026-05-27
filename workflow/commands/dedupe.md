---
description: Scan for ai-kit duplication across 5 surfaces — personal skills/agents shadowing plugin, orphan emitted rules, project hook overlap, and full ecosystem audit (host plugins / MCP / user skills / agents / rules vs ai-kit catalog). Reports only — never deletes.
argument-hint: "[path] [--json] [--fix] [--no-ecosystem]"
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
3. **Surface 5 — Ecosystem audit** — host plugins / MCP servers / user-scope skills / agents / rules checked against ai-kit catalogs. Verdict tokens: `OWNED` (catalogued), `ADOPT` (promote candidate), `REBIND` (scope mismatch / duplicate marketplace), `REPLACE` (user-scope skill/agent shadows plugin equivalent), `EXCLUDED` (installed plugin matches `standards/external/plugins-excluded.json` — ai-kit ships equivalent, uninstall suggested with recorded reason), `DROP-STALE` (path missing on disk), `KEEP-EXTERNAL` (valid out-of-scope). When `divergent > 0`, the dedupe output auto-inlines the per-item verdict table directly under Surface 5 — no second invocation needed. EXCLUDED count is surfaced separately above the table. Suggest running `ai-kit-audit-ecosystem.sh --converge` for the migration recipe.
4. **Cleanup** — if the user passed `--fix`, the script already printed `rm` commands for surfaces 1–3. Show them and **wait for the user to confirm** before executing. Never auto-run the suggested removals. For Surface 5 migrations (`/plugin uninstall`, `/plugin install --scope user`), the same rule applies: surface the commands, never execute.
5. **All-clear** — single line: "No duplicates or orphans found."

For ORPHAN rules where the user wants the rule back, suggest re-running `/ai:recommend-rules` to re-emit the current canonical list. For `ADOPT` candidates from Surface 5, suggest `/ai:followup` to file a catalog-promotion issue.

Don't suggest deletes the script didn't surface, and don't extend cleanup beyond what was reported. `--no-ecosystem` opts out of Surface 5 entirely (legacy four-surface mode).
