# ADR-0019: Run ai-kit on Claude Code, Cursor and GitHub Copilot

## Status

Proposed (2026-10-25)

Supersedes [ADR-0006](0006-scope-claude-code-cursor-only.md) and
[ADR-0010](0010-add-github-copilot-as-rules-only-host.md). Tracked in #229.

## Context

**Why now.** The maintainer works for several clients. One client machine has
only Cursor, another only GitHub Copilot (VS Code agent mode, Copilot CLI, cloud
agent, code review). On the maintainer's laptop Claude Code is the main host, with Cursor
or Copilot now and then. ai-kit only works in Claude Code today: it ships as a
plugin, the `no-globals` and `prefer-plugin` opt-outs stop every global link,
hooks live only in the plugin's `hooks.json`, 11 of 22 commands depend on
`${CLAUDE_PLUGIN_ROOT}`, and skill text names skills as `/ai:tdd`. On a Cursor-only
or Copilot-only machine the whole lifecycle is gone.

**The false premise in ADR-0010.** ADR-0010 rejected Copilot because "Copilot has
no SKILL.md primitive". Copilot shipped Agent Skills on 2025-12-18, so the
premise no longer holds. Skills now load natively in VS Code, the CLI and the
cloud agent. ADR-0006 deleted four emitters and the MCP server for hosts with no
skill primitive; that reasoning does not cover Cursor or Copilot today.

**Verified host capabilities** (docs, 2026-10-25; not yet run live):

| Primitive | Cursor | Copilot (VS Code / CLI / cloud) |
|---|---|---|
| Skills | native, `~/.agents/skills` and project dirs | native on all; cloud reads repo `.github/.claude/.agents/skills` only |
| Rules, global | adapter: no file-based user rules; `alwaysApply` `.mdc` in a local plugin under `~/.cursor/plugins/local` | native in VS Code and CLI via `~/.copilot/copilot-instructions.md` or `~/.copilot/instructions/`; cloud not possible from files |
| Rules, project | `.cursor/rules/*.mdc` (existing emitter) and `AGENTS.md` | new emitter: `.github/instructions/*.instructions.md` or `AGENTS.md` |
| Commands | skills with `disable-model-invocation: true`; `!` shell lines undocumented, assumed not to run (verify item 4) | VS Code `.prompt.md`; CLI reads `.claude/commands`; cloud none. The same skill conversion covers all |
| Subagents | native, reads `~/.claude/agents` | VS Code reads `~/.claude/agents`; CLI needs `~/.copilot/agents/*.agent.md`; cloud needs repo `.github/agents` |
| Hooks | adapter: `~/.cursor/hooks.json`; Cursor docs say it imports Claude Code hooks from `~/.claude/settings.json`; whether it runs the personal ones is unverified (see Consequences) | adapter: `~/.copilot/hooks/*.json` (VS Code preview); cloud repo `.github/hooks` only |

Install in a clean HOME already links 68 skills into Cursor and Copilot paths.
On the maintainer's laptop ai-kit is plugin-only by design (`no-globals` and
`prefer-plugin` set).

## Decision

ai-kit supports three hosts: Claude Code, Cursor and GitHub Copilot.

- **Host paths table.** One data source maps host, primitive and scope to paths
  and formats. install, bootstrap, emit-rules and doctor read it. Nothing else
  hardcodes host paths.
- **Hook adapter.** The existing hook scripts stay the single implementation. A
  thin per-host layer translates the stdin payload and the output. SessionStart,
  SessionEnd, PreToolUse (deny) and PostToolUse (context) port to both hosts.
  Hooks install only with `--with-hooks`.
- **UserPromptSubmit is substituted, not ported.** phase-check and lead-nudge move
  to sessionStart context plus an always-on rule.
- **Install.** `install.sh` works without Claude Code and detects present hosts.
  `prefer-plugin` suppresses only the `~/.claude/*` links that would duplicate the
  plugin, and still links `~/.agents/skills` and Copilot's agent and instruction
  paths to `~/.config/ai-kit/plugin-current`. Claude Code does not read `~/.agents/skills` (its docs), so the plugin stays the only copy there.
- **Root resolver.** Commands and skills find the root through
  `~/.config/ai-kit/root`, not `${CLAUDE_PLUGIN_ROOT}`. The 11 commands become
  skills with `disable-model-invocation: true`.
- **Copilot emitter.** A sibling of the Cursor emitter writes Copilot instruction
  files, project and global.
- **Setup per client repo.** `/ai:setup` asks "local only or committed". Local
  only writes every ai-kit path to `.git/info/exclude`.
- **Skill fallbacks.** Every skill that spawns a subagent or uses AskUserQuestion
  gets a "hosts without X" branch. autonomous, setup and docs-sync are fixed
  first. Skill text names skills host-neutrally.
- **Session coordination stays Claude Code-only.** Claims, peer sessions and the
  lead contract have no equivalent elsewhere.

## Consequences

- Three hosts to test and document instead of two. The sandbox-HOME inventory
  test per host is the guard against path regressions.
- The hook adapter is new code to maintain: each host can change its hook
  payload or output shape.
- UserPromptSubmit context is not portable. Cursor and Copilot get the same
  guidance at session start or as an always-on rule, which is weaker than
  per-prompt injection.
- Setup "local only" has no test (maintainer decision, 2026-10-25). Risk: ai-kit
  files committed into a client repo by mistake.
- Four items must be verified before the matching module is built: whether
  Cursor or VS Code run the personal hooks from `~/.claude/settings.json` (the
  ponytail-review commit gate could block every commit there), whether Cursor's
  third-party import duplicates plugin skills, same-name skill precedence, and
  whether a leading `!` line in a Cursor command runs.
- Cloud agent and code review global instructions live in GitHub settings and
  stay out of scope.
