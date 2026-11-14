# Brief: delivery

Audit how agents, hooks, rules and model settings actually reach a session in the ai-kit repo at `<kit root>`.

## Part 1: one row per agent in `workflow/agents/`

| Agent | model pin | tools | Checklist it applies | Evidence format it returns | Stop rule |

Flag an agent whose checklist omits something a rule or skill says that agent checks.

## Part 2: rule delivery per channel

For each of: main thread (Claude Code), subagent (Claude Code), Cursor. Which rules arrive, how (pathless, `paths:`, injected by a hook, emitted file), and which never arrive. Sources: `workflow/rules/`, `workflow/standards/rules/`, `workflow/bin/lib/emitters/`, the bootstrap emitter (`workflow/bin/bootstrap-project.sh` calling `workflow/bin/emit-rules.sh`), `workflow/hooks/hooks.json`, the kit's own `.claude/settings.json`, `docs/adr/`.

## Part 3: models

Read `~/.claude/settings.json` (keys `model`, `env.CLAUDE_CODE_SUBAGENT_MODEL`), the kit's `.claude/settings.json`, every skill `model:` and every agent pin. Judge them against these facts from the Claude Code docs (re-verify each run): a skill's `model:` applies only for the current turn, and auto mode silently does not apply it when auto mode does not support that model (https://code.claude.com/docs/en/skills.md); subagent model precedence is per-call `model` > agent frontmatter > `CLAUDE_CODE_SUBAGENT_MODEL` > main model (https://code.claude.com/docs/en/sub-agents.md). Report which model each skill and agent actually runs on.

## Part 4: claim versus hook

List every sentence in `workflow/standards/rules/session-coordination.mini.md` and `docs/adr/0017-lead-contract.md` that says something "denies", "blocks", "gates", "is required" or "always". For each, find the hook in `workflow/hooks/` that enforces it and quote the matching line. Verdict per claim: enforced, partly enforced (name the gap: a command form, a tool, a channel the hook does not see), or prompt only.

## Part 5: test coverage

For each skill, agent and hook: the test file in `tests/bin/cases/` or `tests/eval/` that covers it, or "none". Note pins and prompt content that no test asserts.

## Return format

Parts 1 to 5 as tables or one-line lists.
