# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/package-json/v/yusufkaracaburun/ai-kit?filename=mcp%2Fpackage.json&label=version)](VERSION)

**The agile lifecycle as Claude Code + Cursor primitives.** Stack-agnostic. One kit
ships skills, subagents, slash commands, a hook, rules, a plugin manifest, and an
MCP server — pick whichever your host speaks.

| Primitive | Count | Reaches |
| --------- | -----:| ------- |
| Skills | 19 | Claude Code · Cursor |
| Subagents | 2 | Claude Code |
| Slash commands | 5 | Claude Code · Cursor |
| Hooks | 1 | Claude Code |
| Rules | 8 canonical books | Cursor · Claude Code · Aider · Cline · Continue · Cody (via emitter) |
| MCP server | 5 tools | Cline · Continue · Zed · Claude Desktop · anything MCP |

[Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Architecture](docs/architecture.md)

## Requirements

- **Claude Code or Cursor** — the host that loads the skills. Everything starts here.
- **macOS or Linux** with `git` and Bash (the built-in macOS Bash is fine). No build
  step, no package install, no network at runtime.
- **Node 20+** — *only* if you want the MCP server (for Cline / Continue / Zed /
  Claude Desktop). Skip it otherwise.

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
/plugin marketplace add yusufkaracaburun/ai-kit
/plugin install ai-kit@ai-kit
```

See [docs/install-plugin.md](docs/install-plugin.md) for the trade-offs.

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
/setup
```

`/setup` writes `AGENTS.md` + `CONTEXT.md`, symlinks the skills into the project,
drops a `.ai-kit-setup` marker, and detects your stack. The default mode
(`solo-both`) needs no input; three other modes exist for repo-isolation or
brownfield repos — see [ADR-0001](docs/adr/0001-setup-modes.md).

That's it — you're using ai-kit. Some first moves:

- `/aikit-status` — confirm the install is healthy.
- `/grill-me` — stress-test your next idea before you build it.
- `/review` — second pass on a diff before you open the PR.
- Not sure which skill fits? `/aikit-which "I want to ship to production"` ranks the
  best matches.

## The agile lifecycle

ai-kit is 19 skills covering one loop — idea to retro:

| Phase | Skills |
| ----- | ------ |
| Ideation | `grill-me` · `grill-with-docs` · `to-prd` · `prototype` · `zoom-out` |
| Development | `to-issues` → `triage` → `tdd` |
| Testing | `review` · `qa` · `diagnose` |
| Deployment | `ship` |
| Ops & review | `retro` |
| Session continuity | `checkpoint` ↔ `resume` · `handoff` |
| Cross-cutting | `setup` · `recommend-rules` · `improve-codebase-architecture` |

See [docs/mental-model.md](docs/mental-model.md) for the "which skill, when" table and
the lifecycle diagram.

## How it's wired

ai-kit is **standalone** — no runtime daemon, no network calls, no required global
state. Two install layers, run in this order:

1. **Global** *(once per machine, optional)* — `install-global.sh` symlinks skills,
   subagents, slash commands, and the MCP wrapper into `~/.claude/`, `~/.cursor/`,
   etc. The one-line installer does this for you; skip it with `--no-global` if you
   only work in one repo.
2. **Project** *(once per repo)* — `/setup` bootstraps `AGENTS.md`, `CONTEXT.md`,
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
| `/setup` not found | Re-run `install-global.sh`; verify the `setup` symlinks |
| ai-kit root unknown | Set `AI_KIT_ROOT` or run `install-global.sh` once |
| Skills missing in Cursor | Reload the window, check `.cursor/skills` resolves |
| Re-configure a project | `/setup` again (keep/change/skip per branch) or `rm .ai-kit-setup` |
| Usage log empty | `export AI_KIT_USAGE=1` and open a new shell |

Full list: [docs/troubleshooting.md](docs/troubleshooting.md).

## Privacy & local data

ai-kit makes **no network calls** and ships **no telemetry**. It writes three local
files at most: the project `.ai-kit-setup` marker, `~/.config/ai-kit/root`, and —
only when you set `AI_KIT_USAGE=1` — an opt-in skill-usage log at
`~/.local/state/ai-kit/usage.jsonl` (skill name, event, project basename — never
paths, prompts, or file contents). `retro` reads it to ground its questions in
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
