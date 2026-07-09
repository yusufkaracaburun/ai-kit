# ai-kit

[![CI](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml/badge.svg)](https://github.com/yusufkaracaburun/ai-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**The agile lifecycle as Claude Code + Cursor primitives.** Stack-agnostic.
Pure Bash + Markdown. One canonical source emits skills, subagents, slash
commands, hooks, and rules to both hosts — no per-host duplication, no
runtime daemon, no network calls, no telemetry.

| Primitive | Count | Reaches |
| --------- | -----:| ------- |
| Skills | 38 | Claude Code · Cursor |
| Subagents | 3 | Claude Code |
| Slash commands | 11 | Claude Code · Cursor |
| Hooks | 2 | Claude Code |
| Rules | 30 canonical mini-rules | Cursor · Claude Code (via emitter) |
| Curated companions | 21 MCP servers · 25 hook recipes · 12 plugins | Recommend-only — never auto-installed |
| Repo templates | 5 baseline files (`.editorconfig`, `.gitattributes`, `CODEOWNERS`, `renovate.json`, `.envrc`) | Drop-in via `/ai:setup` |

[Mental model](docs/mental-model.md) · [Architecture](docs/architecture.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Install

**Claude Code plugin (recommended).** Self-contained — no global clone, `/plugin update` handles version bumps:

```text
/plugin marketplace add yusufkaracaburun/marketplace
/plugin install ai@yusufkaracaburun
```

The `yusufkaracaburun/marketplace` catalog ([repo](https://github.com/yusufkaracaburun/marketplace))
hosts ai-kit and future plugins behind one stable address.
[docs/install-plugin.md](docs/install-plugin.md) covers scope (user vs. project) + the trade-offs.

**Cursor or other hosts (one-line curl).** Clones into `~/.local/share/ai-kit` and links the skills globally:

```bash
curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
```

- **Project-only** (no machine-wide symlinks): append `-s -- --no-global` to `bash`.
- **Pin a release**: `… | AI_KIT_REF=v1.10.0 bash` (latest at time of writing).
- **Update later**: `~/.local/share/ai-kit/install.sh --update`.

**Are you an AI agent doing the install?** Follow [docs/install-for-agents.md](docs/install-for-agents.md) — a self-contained prompt with detection, verification, and reporting steps.

## First run

In any project, inside Claude Code or Cursor:

```bash
/ai:setup
```

`/ai:setup` writes `AGENTS.md` + `CONTEXT.md`, symlinks the skills into the project,
drops a `.ai-kit-setup` marker, and detects your stack. The default mode
(`solo-both`) needs no input.

First moves:

- `/ai:status` — confirm install is healthy.
- `/ai:grill-me` — stress-test your next idea before you build it.
- `/ai:review` — second pass on a diff before opening the PR.
- `/ai:which "<intent>"` — pick a skill if unsure.

## The agile lifecycle

38 skills covering one loop — idea to retro:

| Phase | Skills |
| ----- | ------ |
| Ideation | `grill-me` · `grill-with-docs` · `to-prd` · `prototype` · `zoom-out` · `should-i-use` |
| Development | `to-issues` → `triage` → `tdd` |
| Testing | `review` · `qa` · `diagnose` |
| Deployment | `ship` |
| Ops & review | `retro` · `feedback` · `contribute-eval` |
| Session continuity | `checkpoint` ↔ `resume` · `handoff` · `onboard` |
| Cross-cutting | `setup` · `setup-gh-workflow` · `recommend-rules` · `recommend-tools` · `improve-codebase-architecture` · `audit-architecture` |
| Automation | `autonomous` (AFK queue drainer — wraps `tdd` → `review` → `ship`) |

11 slash commands: `/ai:setup` · `/ai:doctor` · `/ai:dedupe` · `/ai:status` · `/ai:which` · `/ai:next` · `/ai:upgrade` · `/ai:no-globals` · `/ai:prefer-plugin` · `/ai:hygiene` · `/ai:docs-sync`.

See [docs/mental-model.md](docs/mental-model.md) for the "which skill, when" table and lifecycle diagram.

## Companion tools

ai-kit **wires** companion tools without vendoring them. `/ai:recommend-tools`
detects which fit and writes the integration glue or surfaces the install
command; install the tools from their own upstreams.

**Glue-wired** (ai-kit writes `AGENTS.md` block, Claude Code hook, `wiki/`
scaffold):

- **graphify** — codebase knowledge graph. Scoped subgraph per query instead of raw grep.
- **caveman** — token-compressed agent responses (~65% fewer output tokens).
- **llm-wiki** — self-maintaining knowledge base for non-code documents.

**Recommend-only** (deterministic scorer reads vendored `standards/external/*.json`
tables; user runs the install command):

- **21 MCP servers** — context7, playwright, github, supabase, postgresql,
  stripe, redis, mysql, obsidian, firecrawl, exa, … (full list:
  [`standards/external/mcp-servers.json`](standards/external/mcp-servers.json))
- **25 hook recipes** — prettier-format, eslint-fix, black-isort, ruff, gofmt,
  rustfmt, laravel-pint, phpstan, cargo-clippy, gitleaks-scan, commitlint,
  branch-guard, large-diff-warn, … (full list:
  [`standards/external/hooks-patterns.json`](standards/external/hooks-patterns.json))
- **12 Claude Code plugins** — claude-mem, tdd-guard,
  ask-questions-if-underspecified, claude-md-management, skill-creator,
  github, laravel-boost, frontend-design, lazyweb, chrome-devtools-mcp,
  typescript-lsp, php-lsp (full list:
  [`standards/external/plugins.json`](standards/external/plugins.json))

Glue templates live in [context/templates/companions/](context/templates/companions/);
repo baseline files in [context/templates/repo/](context/templates/repo/).

## Feedback loop

ai-kit at < 50 users has no telemetry pipeline. Real friction surfaces via
two paired skills:

- **`/ai:feedback`** — guided capture of one piece of feedback (friction,
  surprise, clarity, gap, win). Redacts paths + secrets, opens a GitHub
  issue against the ai-kit repo. Never publishes without preview.
- **`/ai:contribute-eval`** — turns a skill failure into a regression test
  (prompt fixture + golden rubric), opens a PR adding both files. Every
  contributed case becomes a regression the next release must pass.

The loop: `/ai:feedback` → `/ai:triage` → strong themes become `/ai:to-prd`
PRDs; specific failures become `/ai:contribute-eval` PRs → CI gate.

## How it's wired

Two install paths, pick one:

1. **Plugin** (Claude Code) — self-contained. `/plugin install` ships everything
   the slash-commands need under `${CLAUDE_PLUGIN_ROOT}`. No global symlinks,
   no clone to maintain.
2. **Global symlinks** (Cursor + Claude Code legacy) — the one-line curl
   installer clones into `~/.local/share/ai-kit` and `install-global.sh`
   symlinks skills, subagents, and commands into `~/.claude/` + `~/.cursor/`.
   Skip with `--no-global` for project-only mode.

Either way, **`/ai:setup`** bootstraps `AGENTS.md`, `CONTEXT.md`, project skills,
and the `.ai-kit-setup` marker — works the same against both install paths.

`AGENTS.md` is the agent-agnostic entry point; skills route from there. Three-layer
source → distribution → host model and per-primitive routing: see
[docs/architecture.md](docs/architecture.md). "I want to add X — which primitive?":
see [docs/primitives.md](docs/primitives.md).

## Troubleshooting

| Issue | First thing to try |
| ----- | ------------------ |
| `/ai:setup` not found | Plugin: re-run `/plugin install ai@yusufkaracaburun` and restart Claude Code. Curl-install: re-run `install-global.sh` and verify the `setup` symlinks |
| ai-kit root unknown | Plugin: `${CLAUDE_PLUGIN_ROOT}` is set by Claude Code — restart it. Curl-install: set `AI_KIT_ROOT` or re-run `install-global.sh` |
| Skills missing in Cursor | Reload the window, check `.cursor/skills` resolves |
| Re-configure a project | `/ai:setup` again (keep/change/skip per branch) or `rm .ai-kit-setup` |
| Usage log empty | `export AI_KIT_USAGE=1` and open a new shell |

Full list: [docs/troubleshooting.md](docs/troubleshooting.md).

## Privacy & local data

No network calls, no telemetry. ai-kit writes three local files at most: the
project `.ai-kit-setup` marker, `~/.config/ai-kit/root`, and — only when
`AI_KIT_USAGE=1` is set — an opt-in skill-usage log at
`~/.local/state/ai-kit/usage.jsonl` (skill name, event, project basename — never
paths, prompts, or file contents). `retro` reads it; `bin/usage-purge.sh`
wipes it. Full data contract + the Claude Code auto-log hook JSON snippet:
[SECURITY.md](SECURITY.md).

The second hook, `bin/hooks/context-drift-check.sh`, is opt-in per project —
`/ai:setup` wires it on request. After an edit it nudges you to update
`CONTEXT.md` or an ADR when you change code those docs name. Deterministic
shell, no LLM, silent when no such docs exist.

## Contributing

Pure Bash + Markdown, no build step. `./tests/bin/run-all.sh` runs the suite in
parallel (≈3.5× faster than the legacy sequential `run-tests.sh`); CI runs the
same on every push. See [CONTRIBUTING.md](CONTRIBUTING.md) for
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
