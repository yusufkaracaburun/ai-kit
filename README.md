# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/package-json/v/yusufkaracaburun/ai-kit?filename=mcp%2Fpackage.json&label=version)](VERSION)

**The agile lifecycle as Claude Code + Cursor primitives.** Stack-agnostic. One kit ships skills, subagents, slash commands, hooks, rules, a plugin manifest, and an MCP server — pick whichever your host speaks.

| Primitive | Count | Reaches |
| --------- | -----:| ------- |
| Skills | 19 | Claude Code · Cursor |
| Subagents | 2 | Claude Code |
| Slash commands | 5 | Claude Code · Cursor |
| Hooks | 1 | Claude Code |
| Rules | 8 canonical books | Cursor · Claude Code · Aider · Cline · Continue · Cody (via emitter) |
| MCP server | 5 tools | Cline · Continue · Zed · Claude Desktop · anything MCP |

See [docs/architecture.md](docs/architecture.md) for how the layers fit together, [docs/primitives.md](docs/primitives.md) for "I want to add X — which primitive?".

**Version:** see [VERSION](VERSION) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Mental model

Two things, do them in this order:

1. **`install-global.sh`** *(once per machine, optional)* — symlinks ai-kit's skills, subagents, slash commands, and the MCP wrapper into `~/.claude/`, `~/.agents/`, `~/.cursor/`, and `~/.local/bin/` so they're discoverable from anywhere. Skip this if you only ever work in one project.
2. **`bootstrap-project.sh` + `/setup`** *(once per project)* — sets up `AGENTS.md`, `CONTEXT.md`, `.claude/skills/`, `.cursor/skills/`, and the `.ai-kit-setup` marker inside the project. **This is project-scoped — works fully without step 1.**

| Setup mode | Step 1 (global) | Step 2 (project) | When |
| ---------- | --------------- | ---------------- | ---- |
| `solo-both` | yes | merge-skills | greenfield default |
| `solo-global` | yes | no-skills | machine-wide only |
| `project-only` | **no** | merge-skills | repo isolation, no host pollution |
| `brownfield` | optional | merge-skills + agent-stack doc | project already has MCP/custom skills/agent-config |

ai-kit is **standalone**: no package-install, no network at runtime, no required global state. `bin/ai-kit-doctor.sh` validates whichever path you chose.

Working in the ai-kit clone itself or want doctor to ignore global checks by default? Run `bin/ai-kit-no-globals.sh on`. A project's own setup-mode (e.g. `solo-both`) still overrides this — projects that *do* use globals stay correctly checked.

## Quick start

**One-line install** (clones into `~/.local/share/ai-kit` and links skills globally):

```bash
curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
```

Project-only install (no host pollution): `... | bash -s -- --no-global`.
Pin a release: `... | AI_KIT_REF=v1.2.0 bash`.
Update later: `... | bash -s -- --update` (or `$AI_KIT_ROOT/install.sh --update`).

**Claude Code plugin (alternative)** — for marketplace-style install + `/plugin update` semantics. Cursor users keep the symlink path above:

```text
/plugin marketplace add yusufkaracaburun/ai-kit
/plugin install ai-kit@ai-kit
```

See [docs/install-plugin.md](docs/install-plugin.md) for details and trade-offs.

Then in any project:

```bash
/setup    # in Claude Code or Cursor — runs bootstrap + dev-environment
```

<details>
<summary>Manual install (or already cloned)</summary>

```bash
git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit
~/.local/share/ai-kit/bin/install-global.sh   # optional: link skills to ~/.claude, ~/.agents, ~/.cursor
```

`ai-kit root` is resolved automatically: `$AI_KIT_ROOT` env → `~/.config/ai-kit/root` → script location. See [install-global prompt](context/prompts/install-global.md) for the agent-driven variant.

</details>

## Agile lifecycle

| Fase | Skills |
| ---- | ------ |
| Ideation | `grill-me`, `grill-with-docs`, `to-prd`, `prototype`, `zoom-out` |
| Development | `to-issues` → `triage` → `tdd` |
| Testing | `review`, `qa`, `diagnose` |
| Deployment | `ship` |
| Ops & Review | `retro` |
| Session continuity | `checkpoint` ↔ `resume` (auto-memory) · `handoff` (cross-machine) |

Framework (Scrum/Kanban): optional via Full setup → `docs/agents/workflow.md`. Architecture: optional branch 7 in Full setup.

Not sure which skill fits? `bin/ai-kit-which.sh "I want to ship this to production"` ranks the top 3 by keyword overlap; `--list` shows all 18, `--explain <skill>` dumps the full `SKILL.md`.

## Cross-tool setup

| Tool | Global skills | Project skills |
| ---- | ------------- | -------------- |
| Claude Code | `~/.agents/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.cursor/skills/` |

Bootstrap symlinks both project paths. `AGENTS.md` is the single agent-agnostic entry point — skills route from there.

## Structure

```
workflow/skills/   19 skills incl. setup, ship, retro
standards/rules/   Book rules (plain markdown — read on-demand by skills)
docs/architecture.md  How the kit is wired (layers, primitives, install paths)
docs/glossary.md      Terms used across ai-kit code and docs
docs/primitives.md    Decision tree: skill vs subagent vs hook vs rule vs MCP
docs/roadmap.md    Forward-looking work (agent-agnostic refactor, smart rule recommender)
orchestration/     Sandcastle templates
context/templates/ Per-project doc templates
context/prompts/   Copy-paste agent prompts (setup)
bin/               Scripts invoked by /setup
.github/workflows/ CI test workflow
tests/bin/         Script regression tests
docs/              Dogfood and internal notes
```

## Setup automation

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/detect-tooling.sh .          # what is in this repo?
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal  # Tier A done
$AI_KIT_ROOT/bin/ai-kit-root.sh               # print resolved root
```

Tier B branch 10 surfaces the `claude-automation-recommender` skill (from `claude-code-setup`) as an opt-in handoff — choice recorded in `.ai-kit-setup`, never auto-run.

## Tests

```bash
./tests/bin/run-tests.sh    # from ai-kit clone
```

CI runs the same suite on push/PR (`.github/workflows/test.yml`).

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for the expanded list. Quick hits:

| Issue | First thing to try |
| ----- | ------------------ |
| `/setup` not found | Re-run `install-global.sh`; verify the two `setup` symlinks |
| ai-kit root unknown | Set `AI_KIT_ROOT` or run `install-global.sh` once |
| Skills missing in Cursor | Reload the window, check `.cursor/skills` resolves |
| Sandcastle placeholder leaked | Edit `.sandcastle/main.mts` install line manually |
| Re-configure project | `/setup` again (keep/change/skip per branch) or `rm .ai-kit-setup` |
| Brownfield rule "lost" | Use `--merge-skills` (default), not `--link-all` |
| Usage log empty | `export AI_KIT_USAGE=1` and open a new shell |

## What ai-kit logs locally (opt-in)

When `AI_KIT_USAGE=1` is set, each invocation of a skill writes one line to
`${XDG_STATE_HOME:-~/.local/state}/ai-kit/usage.jsonl`:

```
{"ts":"2026-05-20T17:14:03Z","skill":"diagnose","event":"start","project":"ai-kit","cwd_hash":"a1b2c3d4e5f6"}
```

Fields: `ts`, `skill`, `event` (`start|done|abort`), `project` (basename of the git root or cwd), `cwd_hash` (sha1 of the absolute path). **Never** the absolute path, prompt contents, file contents, branch names, or anything else. No network calls — CI greps for `curl|wget|/dev/tcp|nc` in the usage scripts to enforce this.

```bash
bin/usage-stats.sh --since=7d        # human report
bin/usage-stats.sh --json            # machine-readable
bin/usage-purge.sh                   # wipe the log
```

`retro` reads `usage-stats.sh` to ground the conversation in observed behaviour. See [SECURITY.md](SECURITY.md) for the full data contract.

### Auto-logging via Claude Code hook

ai-kit ships a `PostToolUse` hook (`bin/hooks/post-skill-log.sh`) wired in
`.claude/settings.json`. When `AI_KIT_USAGE=1` is set, each Skill invocation
auto-writes a `done` event — no per-skill plumbing required. The hook is
silent and no-op without the env var. To add it to a downstream project,
copy this into the project's `.claude/settings.json`:

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

## Eval harness

```bash
./tests/bin/eval-structure.sh        # 8 deterministic SKILL.md checks + fixture lint
./bin/eval-skill.sh diagnose         # dump prompt + SKILL.md + rating template for manual rating
```

Fixtures live in `tests/eval/prompts/<skill>/<scenario>.md`. Rating notes go to `tests/eval/results/` (gitignored). See [docs/eval.md](docs/eval.md).

## License & Provenance

ai-kit is licensed [MIT](LICENSE). It incorporates work from the following MIT-licensed upstreams:

| Upstream | What we took |
| -------- | ------------ |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Workflow skills |
| [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) | Book mini rules |
| [mattpocock/sandcastle](https://github.com/mattpocock/sandcastle) | Sandcastle templates |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Concepts → review, qa, ship |

## Where facts live

- Domain → `CONTEXT.md` · Decisions → `docs/adr/` · Agent config → `docs/agents/`
- Setup state → `.ai-kit-setup` · Commands → official docs via `dev-environment.md`
