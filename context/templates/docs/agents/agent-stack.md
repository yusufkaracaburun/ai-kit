# Agent stack

What coexists with ai-kit in this repo — **brownfield only**. Skip this file on greenfield repos.

## Setup mode

**Mode:** [solo-global | solo-both | project-only | brownfield]

| Location | ai-kit | Custom / other |
| -------- | ------ | -------------- |
| `.cursor/skills/` | [list or "via merge"] | [list] |
| `.agents/skills/` | via merge | n/a |

## Rules

| ai-kit rules | Custom rules |
| ------------ | ------------ |
| [e.g. ai-kit.mdc] | [e.g. coding-standards.mdc] |

## Commands and MCP

- **Commands:** [`.cursor/commands/` entries or n/a]
- **MCP:** [config paths or n/a]

## Coexistence

- ai-kit leads: `/setup`, agile lifecycle, `docs/agents/*`
- Keep separate: [custom skills, plugins, project rules — from user answers]
- Do not overwrite: [list items user chose to preserve]

## Re-run

Run `/setup` branch 0 to change mode. See `.ai-kit-setup` → `branches.setup_mode`.
