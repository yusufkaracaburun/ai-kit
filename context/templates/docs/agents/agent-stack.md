# Agent stack

What coexists with ai-kit in this repo — **brownfield only**. Skip this file on greenfield repos.

## Setup mode

**Mode:** [solo-global | solo-both | project-only | brownfield]

| Location | ai-kit | Custom / other |
| -------- | ------ | -------------- |
| `.cursor/skills/` | [list or "via merge"] | [list] |
| `.agents/skills/` | via merge | n/a |

## Rules (Cursor `.cursor/rules/*.mdc`)

ai-kit does not generate Cursor rules. Any rules below are user-managed.

**Custom rules:** [e.g. coding-standards.mdc]

## Commands and MCP

- **Commands:** [`.cursor/commands/` entries or n/a]
- **MCP:** [config paths or n/a]

## Coexistence

- ai-kit leads: `/ai:setup`, agile lifecycle, `docs/agents/*`
- Keep separate: [custom skills, plugins, project rules — from user answers]
- Do not overwrite: [list items user chose to preserve]

## Re-run

Run `/ai:setup` branch 0 to change mode. See `.ai-kit-setup` → `branches.setup_mode`.
