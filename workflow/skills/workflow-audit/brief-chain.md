# Brief: chain

Audit the idea-to-release skill chain in the ai-kit repo at `<kit root>`.

## Scope

Chain skills under `workflow/skills/`: grill-me, grill-with-docs, validate-idea, to-prd, to-issues, triage, tdd, autonomous, review, qa, diagnose, design-to-code, harvest, retro, checkpoint, resume, next. Plus the rules they lean on: `workflow/standards/rules/` (session-coordination, grill-first, quality-floor, design-leads), `workflow/standards/rules/feedback/deployment-on-demand.mini.md`, and `docs/adr/`.

## Part 1: one row per skill

| Skill | model: | Spawns (agent, model) | Brief contents passed | Gates (MUST / MAY) | Hand-off artefact | Exit criteria |

- "Brief contents": which of criteria, test command, out of scope, key interfaces, decisions in force reach the spawned agent.
- "Hand-off artefact": a file, an issue comment, a label, or "chat only".

## Part 2: findings

1. **Inconsistencies between skills.** Skill A says X, skill B says not X (labels, who reviews, who verifies, file names, order of steps). Cite both sides.
2. **Lead does it itself.** Steps where the skill tells the main thread to edit, build, commit, run a browser or a CLI release op instead of delegating.
3. **Chat-only state.** Output the next skill needs but that lives only in the conversation.
4. **Dangling references.** A path, skill, agent, rule or script named in a skill that does not exist. Check each with `ls` or `grep`.
5. **Stale text.** Version labels, issue numbers, tool names or policies the changelog or an ADR has since replaced.

## Return format

Part 1 table, then Part 2 as five numbered lists, one line per finding: `path:line` (and the opposing `path:line`), what, why it breaks the chain.
