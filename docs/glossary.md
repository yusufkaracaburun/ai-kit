# ai-kit glossary

Alphabetical reference for every term that recurs in ai-kit code, docs, and skills. One canonical definition each — if the same idea has two names, this file picks one and aliases the rest.

For how the terms fit together see [architecture.md](architecture.md); for "which primitive should I reach for?" see [primitives.md](primitives.md).

---

### Agent

The host that runs Claude — the IDE or CLI loading ai-kit's artifacts. ai-kit supports two: Claude Code and Cursor.

**Not** a synonym for *subagent*. A subagent is a child context spawned *by* the agent. When ai-kit docs say "agent-agnostic" they mean "works in any host," not "works in any subagent."

### AGENTS.md

The agent-agnostic project entry-point in every ai-kit-bootstrapped repo. Template lives at `context/templates/AGENTS.md.template`; the bootstrapped copy at `<project>/AGENTS.md` routes the host to skills, rules, and `CONTEXT.md`.

**Not** the same file as `.claude/agents/` or `workflow/agents/`. Those are subagent directories.

### Bootstrap

The act of initializing ai-kit in a project: `bin/bootstrap-project.sh` or running `/ai:setup` in the host. Produces `AGENTS.md`, `CONTEXT.md`, the `.ai-kit-setup` marker, and symlinked skills/agents/commands.

### CHANGELOG.md

Repo-root changelog. Sub-1.0 semver convention: feature additions = minor bump; breaking changes get a `**Breaking**` block.

### CLAUDE.md

Claude Code's project-memory file. ai-kit prefers `AGENTS.md` + `CONTEXT.md` for agent-agnostic reach; users on Claude Code only may keep a `CLAUDE.md` referencing those.

### Command

See *Slash command*.

### CONTEXT.md

The per-project context file: domain model, stack, recent ADRs index. Skills read this first. Template at `context/templates/CONTEXT.md.template`.

### Doctor

`bin/ai-kit-doctor.sh` — diagnostic script that validates the install (global, project, or both) and reports blockers/warnings with exit codes 0/1/2.

### Emitter

A script in `bin/` that converts a single canonical source into one or more derived files. `bin/emit-rules.sh` turns `standards/rules/*.mini.md` into host-specific rule files (Cursor `.mdc`, Claude Code skill text). `bin/emit-agents.sh` keeps a marked region of a subagent's `AGENT.md` generated from named sections of its source `SKILL.md`, so shared reference content has one home.

Use this pattern whenever an artifact needs per-host translation, or shares content with another artifact, in a way a symlink cannot solve.

### Frontmatter

The YAML block between `---` lines at the top of a skill / agent / command file. Fields differ per primitive:
- Skill: `name`, `description` (required)
- Subagent: `name`, `description`, `tools` (required)
- Slash command: `description`, `argument-hint`, `allowed-tools`, `model` (all optional)

### Global channel

The machine-wide path through which ai-kit reaches every project without per-repo files: the Claude Code plugin (`ai@yusufkaracaburun`) or the legacy symlink-install. Recorded per project as `global_channel_available` in `.ai-kit-setup` (ADR-0012). Since ADR-0015 it also carries the *global rules*. Cursor has no global channel.

### Global install

The machine-wide install path. `bin/install-global.sh` creates symlinks under `~/.claude/`, `~/.agents/`, `~/.cursor/`. Opt out per machine with `bin/ai-kit-no-globals.sh on`.

### Global rules

Every `universal: true` + `default_mode: always-on` rule, pre-emitted into the plugin's `rules/` and linked at `~/.claude/rules/ai-kit` by the plugin's SessionStart hook, so Claude Code loads them in every session on the machine (ADR-0015). Pathless ones load at start; `paths:`-scoped ones on touch. Opt-out: `~/.config/ai-kit/no-global-rules`. A project gets per-repo copies only when it has no global channel.

**Not** the same as *stack rules*, which stay per repo.

### Hook

A shell script registered in `.claude/settings.json` (or, for the plugin, `workflow/hooks/hooks.json`) that fires on host events. Plugin-shipped: a PostToolUse hook (`bin/hooks/post-skill-log.sh`) matching `^Skill$` for usage logging, and two SessionStart hooks — `peer-sessions-check.sh` (fires only when other Claude Code sessions are live on the machine; ADR-0014) and `global-rules-link.sh` (keeps `~/.claude/rules/ai-kit` pointing at the plugin's *global rules*; ADR-0015). Project-installed by `/ai:setup`: `search-delegation-check.sh` and `build-delegation-check.sh` (PreToolUse), `phase-check.sh` (UserPromptSubmit).

Event types: `PreToolUse`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`, `Notification`.

### Host

Synonym for *Agent* in the "IDE / CLI" sense. This glossary uses *agent* for that meaning and reserves *host* for ambiguous contexts where "agent" could be misread as "subagent."

### Marker

The `.ai-kit-setup` file at a project root. Indicates the project has been bootstrapped and records the setup mode (`solo-both`, `project-only`, `brownfield`, etc.). Written by `bin/write-setup-marker.sh`.

### Plugin

A Claude Code distributable bundle of skills + agents + commands, defined by `workflow/.claude-plugin/plugin.json` and catalogued in `.claude-plugin/marketplace.json`. **Claude Code-only**; Cursor users keep using the symlink install.

### PostToolUse hook

A hook event firing after a tool call completes. ai-kit's current hook matches `^Skill$` and logs to local usage stats.

### Primitive

Any first-class artifact type that the host loads: skill, subagent, slash command, hook, rule. The two non-host primitives are *emitter* and *template*.

### Project-only install

Setup mode that skips `install-global.sh` — only the project gets ai-kit assets. Picks: solo developers who want repo isolation, or shared machines where global symlinks would pollute another user's setup.

### Rule

Agent-agnostic guidance derived from canonical books, stored in `standards/rules/<name>.mini.md` or `.nano.md`. 45 mini-rules shipped today (`ls standards/rules/`). Emitted per host by `bin/emit-rules.sh`.

### Setup

The `/ai:setup` skill (`workflow/skills/setup/SKILL.md`) — the user-facing entry point for project initialization. Wraps `bootstrap-project.sh` and `detect-tooling.sh`.

### Skill

A workflow with `name:` + `description:` frontmatter, auto-discovered by the host. Lives at `workflow/skills/<name>/SKILL.md`. The primary ai-kit primitive — 33 shipped today.

When the host sees a user intent matching a skill's `description`, it loads the SKILL.md body on demand.

### Slash command

A prompt template invoked by `/<name>` in the host. File: `workflow/commands/<name>.md`. Difference from skill: a slash command is *user-invoked* with optional `$ARGUMENTS`, processed before the model sees it; a skill is *auto-discovered* by description match.

### Stack rule

A rule with `universal: false` and a `paths:` scope (laravel-conventions, flutter-conventions, tailwind, …). Chosen per project by `recommend-rules`, emitted into that repo's `.claude/rules/`; the only rules `/ai:setup` still writes into a plugin-served Claude Code repo (ADR-0015).

### Subagent

A Claude Code primitive: an isolated child context spawned via the Task tool. Definition: `workflow/agents/<name>/AGENT.md`. Use when a skill needs to do heavy work without polluting the main context.

**Cursor and other hosts have no subagent primitive** — skills that delegate must include an inline fallback.

### Symlink install

The default ai-kit distribution mechanism: `bin/install-global.sh` creates symbolic links from `~/.claude/skills/`, `~/.cursor/skills/`, etc., back to `~/.local/share/ai-kit/workflow/skills/`. Updates propagate via `git pull` in the source repo.

### Template

A file under `context/templates/` (or `orchestration/`) that `bootstrap-project.sh` copies — with light variable expansion — into a fresh project. Distinct from *emitter*: templates are mostly literal; emitters transform.

### VERSION

The single-source-of-truth version file at the repo root. All derived version fields (plugin manifest, marketplace catalog) must mirror it. `bin/sync-plugin-version.sh` enforces this.

---

## Aliases

- "agent" (host sense) = "host" — this glossary uses *agent*
- "agent" (subagent sense) = "subagent" — this glossary uses *subagent*; never the bare word
- "command" = "slash command" — full name preferred to avoid confusion with `bin/` scripts
- "doctor" = `bin/ai-kit-doctor.sh`
- "the kit" / "ai-kit" — the repository
