# ai-kit architecture

How the kit is wired across the file system, the host (Claude Code or Cursor), and the primitives it ships.

Read this before adding a new primitive type or moving files between layers. For terminology see [glossary.md](glossary.md); for the "which primitive should I use?" decision tree see [primitives.md](primitives.md).

## Three layers

1. **Source layer** — the ai-kit repository (`~/.local/share/ai-kit/` after install). Single source of truth for skills, agents, commands, rules, hooks, and templates.
2. **Distribution layer** — scripts and manifests that hand artifacts to the host: `bin/install-global.sh` (symlinks), `bin/bootstrap-project.sh` (per-project), the Claude Code plugin (`workflow/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`).
3. **Host layer** — the IDE/CLI that loads the artifacts: Claude Code or Cursor.

```
┌─────────────────────── source layer ────────────────────────┐
│  workflow/skills/        37 skills (SKILL.md)               │
│  workflow/agents/        3 subagents (AGENT.md)             │
│  workflow/commands/      10 slash commands (.md)            │
│  standards/rules/        agent-agnostic rule books          │
│  .claude/settings.json   PostToolUse hook (Skill→log)       │
│  context/templates/      per-project doc templates          │
│  bin/                    scripts (install, doctor, emit…)   │
└────────────────────────────┬────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────────┐
        ▼                    ▼                        ▼
  ┌──────────────┐    ┌───────────────┐      ┌────────────────┐
  │ install-     │    │ bootstrap-    │      │ .claude-plugin/│
  │ global.sh    │    │ project.sh    │      │ + marketplace  │
  │ (symlinks)   │    │ (per-project) │      │ (Claude Code)  │
  └──────┬───────┘    └───────┬───────┘      └────────┬───────┘
         │                    │                       │
         ▼                    ▼                       ▼
  ~/.claude/skills/    <proj>/.claude/skills/   Claude Code
  ~/.claude/agents/    <proj>/.claude/agents/    plugin loader
  ~/.claude/commands/  <proj>/.claude/commands/  (skills, agents,
  ~/.agents/skills/    <proj>/.cursor/skills/    commands, hooks)
  ~/.cursor/skills/    <proj>/AGENTS.md
                       <proj>/CONTEXT.md
                       <proj>/.ai-kit-setup
```

## How a primitive reaches the host

| Primitive | Source path | Reaches host via | Host directory |
|---|---|---|---|
| Skill | `workflow/skills/<name>/SKILL.md` | symlink (install-global.sh / bootstrap) **or** plugin manifest | `~/.claude/skills/` · `~/.cursor/skills/` · `<proj>/.claude/skills/` |
| Subagent | `workflow/agents/<name>/AGENT.md` | same symlink pass + plugin manifest | `~/.claude/agents/` · `<proj>/.claude/agents/` |
| Slash command | `workflow/commands/<name>.md` | same symlink pass (files, not dirs) + plugin manifest | `~/.claude/commands/` · `<proj>/.claude/commands/` |
| Rule | `standards/rules/<name>.mini.md` | **emitter** (`bin/emit-rules.sh`) at `/ai:setup` time — converts to host format | `<proj>/.cursor/rules/*.mdc` (Cursor) · skill text (Claude Code) |
| Hook | `.claude/settings.json` + `bin/hooks/*.sh` | committed in the project (or emitted by `/ai:setup`) | `<proj>/.claude/settings.json` |

## Two design choices that keep the kit coherent

### 1. Symlinks, not copies

`install-global.sh` and `bootstrap-project.sh` create symlinks back to the source layer. A `git pull` in `~/.local/share/ai-kit` instantly updates every host. The plugin follows the same principle: its manifest *points at* repo paths rather than copying them.

Consequence: never write into `~/.claude/skills/<name>/` or `<proj>/.claude/skills/<name>/` directly — that path is a symlink. Edit the source under `workflow/skills/`.

### 2. Emitter pattern: one source, derived artifacts

An emitter reads one canonical source and writes derived files that cannot simply be symlinked.

**`bin/emit-rules.sh`** — rules are agent-agnostic markdown books (`standards/rules/`). Each host expects a different rule format (Cursor `.mdc`, Claude Code skill-text, etc.), so the emitter writes host-specific files into the *target project* at `/ai:setup` time.

**`bin/emit-agents.sh`** — a subagent prompt (`workflow/agents/<name>/AGENT.md`) and its companion skill (`workflow/skills/<name>/SKILL.md`) share reference content: the review checklist, the output-format spec. The emitter keeps a marked region of `AGENT.md` generated verbatim from named `SKILL.md` sections, so the shared text has a single home. It runs at *authoring* time inside ai-kit's own tree; CI runs `emit-agents.sh --check` and fails the build on drift.

Use this pattern whenever an artifact needs per-host transformation, or shares content with another artifact. Don't invent a parallel system.

## Primitive co-existence rules

- **Multiple install paths can co-exist.** A user can have symlink-install + plugin install at the same time. `bin/ai-kit-doctor.sh` detects this and warns (one channel becomes stale on update).
- **Per-project always overrides global.** `<proj>/.claude/skills/foo/` wins over `~/.claude/skills/foo/`. Use project-scope to pin a version or override for one repo.
- **Subagents are Claude Code-only.** Skills that delegate to a subagent must include an **inline fallback** for Cursor, which has no Task tool. See `workflow/skills/review/SKILL.md` for the canonical pattern.
- **Slash commands are Claude Code-first.** `~/.cursor/commands/` is mirrored opportunistically; verify per Cursor version.

## Versioning

`VERSION` is the single authority. One derived artifact must stay in sync
in-repo:

- `workflow/.claude-plugin/plugin.json:version`

`bin/sync-plugin-version.sh` re-stamps it from `VERSION`. CI asserts equality.

The plugin marketplace catalog lives in a **separate repo**
(`yusufkaracaburun/marketplace`) since 2026-05-23 — one catalog for all
`yusufkaracaburun` plugins. Its `.claude-plugin/marketplace.json` pins each
plugin's `source.ref` to a release tag and must be bumped manually after
every ai-kit release; `bin/release.sh` prints the copy-paste command.

## Where to put new things

| You want to add … | Put it in … |
|---|---|
| A new workflow with `name:` + `description:` frontmatter | `workflow/skills/<name>/SKILL.md` |
| An isolated context worker for one specific task | `workflow/agents/<name>/AGENT.md` |
| A short prompt-template invoked by `/<name>` | `workflow/commands/<name>.md` |
| Cross-cutting guidance applicable to every host | `standards/rules/<name>.mini.md` + extend `bin/emit-rules.sh` |
| A behavior triggered by tool events | `bin/hooks/<name>.sh` + register in `.claude/settings.json` |
| A user-facing diagnostic script | `bin/ai-kit-<name>.sh` — and wrap it as a slash command |

If your answer is "two of these at once," step back: usually one is primary and the other should defer to it.

## Open follow-ups

All five primitive types (skill, subagent, slash command, hook, rule) are
landed and documented above. Remaining work is tracked in
[roadmap.md](roadmap.md) — chiefly Cursor `.cursor/commands/` runtime verification
and bundling the hook in the plugin.

## See also

- [glossary.md](glossary.md) — definitions of every term used above
- [primitives.md](primitives.md) — "I want to automate X — which primitive?"
- [roadmap.md](roadmap.md) — what's coming next
- [mental-model.md](mental-model.md) — the lifecycle loop and skill choreography
