# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**The agile lifecycle as Claude Code + Cursor primitives.** Stack-agnostic.
Pure Bash + Markdown. One canonical source emits skills, subagents, slash
commands, hooks, and rules to both hosts — no per-host duplication, no
runtime daemon, no network calls, no telemetry.

| Primitive | Count | Reaches |
| --------- | -----:| ------- |
| Skills | 21 | Claude Code · Cursor |
| Subagents | 3 | Claude Code |
| Slash commands | 6 | Claude Code · Cursor |
| Hooks | 2 | Claude Code |
| Rules | 8 canonical books | Cursor · Claude Code (via emitter) |

[Mental model](docs/mental-model.md) · [Architecture](docs/architecture.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Install

One line — clones into `~/.local/share/ai-kit` and links the skills globally:

```bash
curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
```

- **Project-only** (no machine-wide symlinks): append `-s -- --no-global` to `bash`.
- **Pin a release**: `… | AI_KIT_REF=v1.2.0 bash`.
- **Update later**: `~/.local/share/ai-kit/install.sh --update`.

**Claude Code plugin (alternative).** Marketplace-style install with `/plugin update`
semantics — Claude Code only:

```text
/plugin marketplace add yusufkaracaburun/marketplace
/plugin install ai-kit@yusufkaracaburun
```

The `yusufkaracaburun/marketplace` catalog ([repo](https://github.com/yusufkaracaburun/marketplace))
hosts ai-kit and future plugins behind one stable address. See
[docs/install-plugin.md](docs/install-plugin.md) for the trade-offs.

**Are you an AI agent doing the install?** Follow [docs/install-for-agents.md](docs/install-for-agents.md) — a self-contained prompt with detection, verification, and reporting steps.

## First run

In any project, inside Claude Code or Cursor:

```bash
/aikit-setup
```

`/aikit-setup` writes `AGENTS.md` + `CONTEXT.md`, symlinks the skills into the project,
drops a `.ai-kit-setup` marker, and detects your stack. The default mode
(`solo-both`) needs no input.

First moves:

- `/aikit-status` — confirm install is healthy.
- `/aikit-grill-me` — stress-test your next idea before you build it.
- `/aikit-review` — second pass on a diff before opening the PR.
- `/aikit-which "<intent>"` — pick a skill if unsure.

## The agile lifecycle

21 skills covering one loop — idea to retro:

| Phase | Skills |
| ----- | ------ |
| Ideation | `aikit-grill-me` · `aikit-grill-with-docs` · `aikit-to-prd` · `aikit-prototype` · `aikit-zoom-out` |
| Development | `aikit-to-issues` → `aikit-triage` → `aikit-tdd` |
| Testing | `aikit-review` · `aikit-qa` · `aikit-diagnose` |
| Deployment | `aikit-ship` |
| Ops & review | `aikit-retro` · `aikit-followup` |
| Session continuity | `aikit-checkpoint` ↔ `aikit-resume` · `aikit-handoff` |
| Cross-cutting | `aikit-setup` · `aikit-recommend-rules` · `aikit-recommend-tools` · `aikit-improve-codebase-architecture` |

See [docs/mental-model.md](docs/mental-model.md) for the "which skill, when" table and lifecycle diagram.

## Companion tools

ai-kit **wires** three companions without vendoring them. `/aikit-recommend-tools`
detects which fit and writes the integration glue (`AGENTS.md` block, Claude Code
hook, `wiki/` scaffold); install the tools from their own upstreams.

- **graphify** — codebase knowledge graph. Scoped subgraph per query instead of raw grep.
- **caveman** — token-compressed agent responses (~65% fewer output tokens).
- **llm-wiki** — self-maintaining knowledge base for non-code documents.

Glue lives in [context/templates/companions/](context/templates/companions/).

## How it's wired

Two install layers, both optional:

1. **Global** — `install-global.sh` symlinks skills, subagents, and commands into
   `~/.claude/` and `~/.cursor/`. The one-line installer does this; skip with
   `--no-global` if you only work in one repo.
2. **Project** — `/aikit-setup` bootstraps `AGENTS.md`, `CONTEXT.md`, project skills,
   and the `.ai-kit-setup` marker. Works fully without step 1.

`AGENTS.md` is the agent-agnostic entry point; skills route from there. Three-layer
source → distribution → host model and per-primitive routing: see
[docs/architecture.md](docs/architecture.md). "I want to add X — which primitive?":
see [docs/primitives.md](docs/primitives.md).

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

No network calls, no telemetry. ai-kit writes three local files at most: the
project `.ai-kit-setup` marker, `~/.config/ai-kit/root`, and — only when
`AI_KIT_USAGE=1` is set — an opt-in skill-usage log at
`~/.local/state/ai-kit/usage.jsonl` (skill name, event, project basename — never
paths, prompts, or file contents). `aikit-retro` reads it; `bin/usage-purge.sh`
wipes it. Full data contract + the Claude Code auto-log hook JSON snippet:
[SECURITY.md](SECURITY.md).

The second hook, `bin/hooks/context-drift-check.sh`, is opt-in per project —
`/aikit-setup` wires it on request. After an edit it nudges you to update
`CONTEXT.md` or an ADR when you change code those docs name. Deterministic
shell, no LLM, silent when no such docs exist.

## Contributing

Pure Bash + Markdown, no build step. `./tests/bin/run-tests.sh` runs the suite; CI
runs the same on every push. See [CONTRIBUTING.md](CONTRIBUTING.md) for
skill-authoring rules and [docs/eval.md](docs/eval.md) for the eval harness.

## License & provenance

ai-kit is licensed [MIT](LICENSE). It incorporates work from these MIT-licensed
upstreams:

| Upstream | What we took |
| -------- | ------------ |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Workflow skills |
| [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) | Book mini rules |
| [mattpocock/sandcastle](https://github.com/mattpocock/sandcastle) | Sandcastle templates |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Concepts → review, qa, ship |
