# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**The agile lifecycle as Claude Code + Cursor primitives.** Stack-agnostic. One kit
ships skills, subagents, slash commands, hooks, rules, and a Claude Code plugin
manifest — for the two hosts ai-kit supports: Claude Code and Cursor.

## Goal

Turn ad-hoc AI-pair-programming into a disciplined, repeatable agile lifecycle
that the agent can actually run.

Concretely, ai-kit aims to:

- **Make the lifecycle first-class.** Ideation → plan → execute → review → ship →
  retro lives as named primitives the agent (and the human) can invoke by name,
  not as oral tradition or per-project copy-paste.
- **Single source of truth across two hosts.** One canonical skill body emits the
  Claude Code, Cursor, and rule-index variants — no per-host duplication, no
  drift.
- **Stay stack-agnostic and zero-runtime.** No build step, no network at runtime,
  no per-language assumptions; Bash + Markdown + a small JSON manifest, so the
  same kit works on a Laravel monorepo and a Vue prototype.
- **Be plumbing, not policy.** ai-kit gives the agent disciplined moves
  (TDD loop, code review, ship, retro, diagnose); the project — your CLAUDE.md,
  your CONTEXT.md, your ADRs — supplies the policy. The kit never overwrites
  what you wrote.
- **Stay opt-in and observable.** Every cross-cutting feature (usage logging,
  rule emission, web-search caching, plugin install) is opt-in by env var or
  explicit flag; no silent telemetry; everything is grep-able shell.

If you want a deeper picture: [docs/mental-model.md](docs/mental-model.md) maps
the skill set to the lifecycle, and [docs/architecture.md](docs/architecture.md)
explains the three-layer source → distribution → host model.

| Primitive | Count | Reaches |
| --------- | -----:| ------- |
| Skills | 20 | Claude Code · Cursor |
| Subagents | 3 | Claude Code |
| Slash commands | 5 | Claude Code · Cursor |
| Hooks | 2 | Claude Code |
| Rules | 8 canonical books | Cursor · Claude Code (via emitter) |

[Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Architecture](docs/architecture.md)

## Install

One line — clones into `~/.local/share/ai-kit` and links the skills so every project
finds them:

```bash
curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
```

- **Project-only** (no machine-wide symlinks): append `-s -- --no-global` to `bash`.
- **Pin a release**: run the pipe as `… | AI_KIT_REF=v1.2.0 bash`.
- **Update later**: `~/.local/share/ai-kit/install.sh --update`.

**Claude Code plugin (alternative).** Marketplace-style install with `/plugin update`
semantics — Claude Code only; Cursor users keep the line above:

```text
/plugin marketplace add yusufkaracaburun/marketplace
/plugin install ai-kit@yusufkaracaburun
```

The `yusufkaracaburun/marketplace` catalog ([repo](https://github.com/yusufkaracaburun/marketplace))
hosts ai-kit and future plugins behind one stable address — add it once.

See [docs/install-plugin.md](docs/install-plugin.md) for the trade-offs and the
deprecation note on the pre-3.0 `marketplace add yusufkaracaburun/ai-kit` path.

<details>
<summary>Manual install (or already cloned)</summary>

```bash
git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit
~/.local/share/ai-kit/bin/install-global.sh   # optional: link skills globally
```

ai-kit root resolves automatically: `$AI_KIT_ROOT` env → `~/.config/ai-kit/root` →
script location.

</details>

## First run

In any project, inside Claude Code or Cursor:

```bash
/aikit-setup
```

`/aikit-setup` writes `AGENTS.md` + `CONTEXT.md`, symlinks the skills into the project,
drops a `.ai-kit-setup` marker, and detects your stack. The default mode
(`solo-both`) needs no input; three other modes exist for repo-isolation or
brownfield repos — see [ADR-0001](docs/adr/0001-setup-modes.md).

That's it — you're using ai-kit. Some first moves:

- `/aikit-status` — confirm the install is healthy.
- `/aikit-grill-me` — stress-test your next idea before you build it.
- `/aikit-review` — second pass on a diff before you open the PR.
- Not sure which skill fits? `/aikit-which "I want to ship to production"` ranks the
  best matches.

## For AI agents

If you are an AI agent (Claude Code, Cursor, or another tool-using LLM) and the
human has asked you to "install ai-kit", "set up ai-kit", or "configure ai-kit
for this project", paste the prompt below into your own context and execute it.
It is self-contained — no extra explanation from the human is required.

````text
Goal: install ai-kit on this machine and configure it for the current project.
ai-kit is a Claude Code + Cursor primitive bundle for the agile lifecycle
(ideation → ship → retro). Repo: https://github.com/yusufkaracaburun/ai-kit.

Plan (run in order; stop on the first failure and report it):

1. Detect host. Check for one or more of:
   - `~/.claude/` (Claude Code)
   - `.cursor/` in the user's current project (Cursor)
   If neither is present, ask the human which host they use before proceeding.

2. Detect existing install. If `~/.local/share/ai-kit/` already exists and
   `~/.local/share/ai-kit/VERSION` is readable, skip step 3 and go to step 4.

3. Install ai-kit globally (one line, no sudo, no build step, no network at
   runtime after this):

       curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash

   This clones to `~/.local/share/ai-kit/` and links the skills so every
   project finds them. If `curl` is unavailable, fall back to:

       git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit
       ~/.local/share/ai-kit/bin/install-global.sh

4. Verify the install. Run:

       ~/.local/share/ai-kit/bin/ai-kit-doctor.sh

   Expect exit code 0 and no `BLOCKER` lines. If `BLOCKER` lines exist, surface
   them verbatim to the human and stop.

5. Bootstrap the current project. From the project root, invoke the
   `/aikit-setup` skill (Claude Code: `/aikit-setup`; Cursor: invoke the
   `aikit-setup` skill). Default mode (`solo-both`) is correct unless the
   human has already specified another mode. After it completes, confirm
   `.ai-kit-setup` exists in the project root.

6. Confirm health. Run `/aikit-status` (or `~/.local/share/ai-kit/bin/ai-kit-status.sh`)
   and report the version, the host(s) it detected, and the rule emission
   summary back to the human.

7. Suggest two next moves, picked from the human's intent:
   - If they want to ship: `/aikit-ship` flow.
   - If they want to plan: `/aikit-grill-me` to stress-test the plan first.
   - If they are unsure: `/aikit-which "<one-line intent>"` to pick a skill.

Rules:
- Do not modify the human's existing `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`,
  `.claude/`, or `.cursor/` content beyond what `/aikit-setup` does itself.
- No telemetry, no network calls beyond the initial clone — ai-kit is shell +
  markdown only at runtime.
- Opt-in usage logging is OFF unless the human explicitly asks for it (then
  set `AI_KIT_USAGE=1` in their shell profile).
- If any step writes outside `~/.local/share/ai-kit/` or the current project,
  stop and ask the human first.

Report at the end: install version, host(s) detected, skills/subagents/commands
counted, any blockers, and the two suggested next moves.
````

If your model supports it, hand the prompt above to a sub-agent so its output
does not pollute the parent conversation.

## The agile lifecycle

ai-kit is 21 skills covering one loop — idea to retro:

| Phase | Skills |
| ----- | ------ |
| Ideation | `aikit-grill-me` · `aikit-grill-with-docs` · `aikit-to-prd` · `aikit-prototype` · `aikit-zoom-out` |
| Development | `aikit-to-issues` → `aikit-triage` → `aikit-tdd` |
| Testing | `aikit-review` · `aikit-qa` · `aikit-diagnose` |
| Deployment | `aikit-ship` |
| Ops & review | `aikit-retro` · `aikit-followup` |
| Session continuity | `aikit-checkpoint` ↔ `aikit-resume` · `aikit-handoff` |
| Cross-cutting | `aikit-setup` · `aikit-recommend-rules` · `aikit-recommend-tools` · `aikit-improve-codebase-architecture` |

See [docs/mental-model.md](docs/mental-model.md) for the "which skill, when" table and
the lifecycle diagram.

## Companion tools

ai-kit ships the agile lifecycle. Three companions pair well with it — ai-kit
**wires them, but never vendors them**:

- **graphify** — a knowledge graph of your codebase. Returns a scoped subgraph per
  query instead of raw grep; a large token cut on multi-file repos.
- **caveman** — token-compressed agent responses (~65% fewer output tokens). An
  opt-in communication mode.
- **llm-wiki** — a self-maintaining knowledge base. Ingests non-code documents
  (specs, transcripts, research) into an interlinked wiki the agent keeps current;
  the wiki, not the raw files, is the artifact that compounds.

`/aikit-recommend-tools` detects which of these fit, then writes the integration glue —
an `AGENTS.md` rules block, a Claude Code hook, a `wiki/` scaffold — without
copying any upstream source into your repo. Install the tools from their own
upstreams; ai-kit only configures them. Glue lives in
[context/templates/companions/](context/templates/companions/).

## How it's wired

ai-kit is **standalone** — no runtime daemon, no network calls, no required global
state. Two install layers, run in this order:

1. **Global** *(once per machine, optional)* — `install-global.sh` symlinks skills,
   subagents, and slash commands into `~/.claude/`, `~/.cursor/`, etc. The one-line
   installer does this for you; skip it with `--no-global` if you only work in one
   repo.
2. **Project** *(once per repo)* — `/aikit-setup` bootstraps `AGENTS.md`, `CONTEXT.md`,
   project skills, and the `.ai-kit-setup` marker. Works fully without step 1.

`AGENTS.md` is the single agent-agnostic entry point; skills route from there. Skill
paths per tool:

| Tool | Global | Project |
| ---- | ------ | ------- |
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Cursor | `~/.cursor/skills/` | `.cursor/skills/` |

`bin/ai-kit-doctor.sh` (or `/aikit-doctor`) validates whichever path you chose. For
the three-layer model and per-primitive routing, see
[docs/architecture.md](docs/architecture.md); for "I want to add X — which
primitive?" see [docs/primitives.md](docs/primitives.md).

## Troubleshooting

| Issue | First thing to try |
| ----- | ------------------ |
| `/aikit-setup` not found | Re-run `install-global.sh`; verify the `aikit-setup` symlinks |
| ai-kit root unknown | Set `AI_KIT_ROOT` or run `install-global.sh` once |
| Skills missing in Cursor | Reload the window, check `.cursor/skills` resolves |
| Re-configure a project | `/aikit-setup` again (keep/change/skip per branch) or `rm .ai-kit-setup` |
| Usage log empty | `export AI_KIT_USAGE=1` and open a new shell |

Full list: [docs/troubleshooting.md](docs/troubleshooting.md).

## Privacy & local data

ai-kit makes **no network calls** and ships **no telemetry**. It writes three local
files at most: the project `.ai-kit-setup` marker, `~/.config/ai-kit/root`, and —
only when you set `AI_KIT_USAGE=1` — an opt-in skill-usage log at
`~/.local/state/ai-kit/usage.jsonl` (skill name, event, project basename — never
paths, prompts, or file contents). `aikit-retro` reads it to ground its questions in
observed behaviour; `bin/usage-purge.sh` wipes it. Full data contract:
[SECURITY.md](SECURITY.md).

<details>
<summary>Auto-log skill invocations via a Claude Code hook</summary>

ai-kit ships a `PostToolUse` hook (`bin/hooks/post-skill-log.sh`) wired in its own
`.claude/settings.json`. With `AI_KIT_USAGE=1` set, each Skill invocation auto-writes
a `done` event — no per-skill plumbing. The hook is silent and no-op without the env
var. To add it to a downstream project, copy this into its `.claude/settings.json`:

```jsonc
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "^Skill$",
      "hooks": [{
        "type": "command",
        "command": "${AI_KIT_ROOT}/bin/hooks/post-skill-log.sh"
      }]
    }]
  }
}
```

</details>

The second hook, `bin/hooks/context-drift-check.sh`, is opt-in per project —
`/aikit-setup` wires it on request via `bin/apply-context-drift-hook.sh`. After
an edit it nudges you to update `CONTEXT.md` or an ADR when you change code those
docs name. Deterministic shell, no LLM, silent when no such docs exist.

## Contributing

Pure Bash + Markdown, no build step. `./tests/bin/run-tests.sh` runs the suite; CI
runs the same on every push. See [CONTRIBUTING.md](CONTRIBUTING.md) for skill-authoring
rules and [docs/eval.md](docs/eval.md) for the eval harness.

## License & provenance

ai-kit is licensed [MIT](LICENSE). It incorporates work from these MIT-licensed
upstreams:

| Upstream | What we took |
| -------- | ------------ |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Workflow skills |
| [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) | Book mini rules |
| [mattpocock/sandcastle](https://github.com/mattpocock/sandcastle) | Sandcastle templates |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Concepts → review, qa, ship |
