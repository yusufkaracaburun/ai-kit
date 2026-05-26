# Companion tool glue

Integration glue for **companion tools** — third-party AI-productivity tools that
sit alongside ai-kit but are not part of its agile lifecycle. The `recommend-tools`
skill reads these templates and wires whichever tools the user picks.

ai-kit's rule here: **wire, do not vendor.** The tool installs from its own
upstream; ai-kit owns only the integration glue in this directory. Same pattern as
`recommend-rules` for community rule packs — see
[docs/architecture.md](../../../docs/architecture.md).

| File | Companion | Goes into |
| ---- | --------- | --------- |
| `graphify.md` | graphify | project `AGENTS.md` (agent-agnostic rules block) |
| `graphify-hook.json` | graphify | project `.claude/settings.json` (Claude Code `PreToolUse` hook) |
| `graphifyignore` | graphify | project `.graphifyignore` (root) — copied verbatim, skip-if-present |
| `caveman.md` | caveman | project `AGENTS.md` (opt-in note) |
| `llm-wiki/` | llm-wiki | project `wiki/` + `raw/` skeleton + `AGENTS.md` pointer |

Adding a new companion tool: drop its glue here and add a row to the table in
`workflow/skills/recommend-tools/SKILL.md`.
