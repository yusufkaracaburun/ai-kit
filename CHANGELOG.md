# Changelog

## 1.0.0 — first release

- **Setup trim:** one `setup_mode` question replaces agent-stack + global/project/both split
- **Fast path (Tier A):** mode + bootstrap + dev-env; `--tier=minimal` + `verify-setup --minimal`
- **Brownfield-only** `agent-stack.md`; auto-draft via `detect-tooling --write-agent-stack`
- Setup modes: `solo-both` | `solo-global` | `project-only` | `brownfield`
- `merge-skills` bootstrap default preserved; `--link-all` still available
- 45+ script tests, CI workflow

## 0.4.0

- **Agent stack** branch (setup branch 0): inventariseert bestaande skills, rules, commands, MCP
- `detect_agent_stack()` in `detect-tooling.sh --json`; nested `.cursor/**/*.mdc` support
- Bootstrap: `--merge-skills` (default), `--link-all`, `--no-skills`
- Template `docs/agents/agent-stack.md`; `agent-stack-guide.md`
- `write-setup-marker.sh --agent-stack=`; verify respects global-only + agent-stack.md
- GitHub Actions CI for `tests/bin/run-tests.sh`
- Dogfood notes: [docs/dogfood-portal.md](docs/dogfood-portal.md)

## 0.3.2

- Portable ai-kit root: `$AI_KIT_ROOT` env, `~/.config/ai-kit/root`, or script location
- `bin/lib/ai-kit-root.sh`, `bin/ai-kit-root.sh`; `install-global.sh` writes config
- Replaced hardcoded `~/ws/ai-kit` in prompts, skills, and README

## 0.3.1

- Agent copy-paste prompts: `context/prompts/setup-project.md`, `install-global.md`
- Setup prompt: explicit **global | project | both** skills scope choice before scripts run
- `bootstrap-project.sh --no-skills` for global-only scope (templates without project skill symlinks)
- README quick start points to project setup prompt as primary flow

## 0.3.0

- Architecture branch in `/setup` (branch 6): optional `docs/agents/architecture.md`, `architecture-guide.md`
- Setup automation: `detect-lib.sh`, `detect-tooling.sh`, `verify-setup.sh`, `write-setup-marker.sh`, `automation-guide.md`
- `detect_architecture` heuristics (FE/BE patterns, monorepo) in tooling JSON
- Cross-refs: AGENTS template, domain.md, `improve-codebase-architecture`, `grill-with-docs`
- Fixtures and tests for architecture detection and setup scripts

## 0.2.0

- Intelligent `/setup` with grill-me decision tree and `.ai-kit-setup` marker
- Stack-agnostic: removed curated stacks; official docs lookup in dev-environment
- Cross-tool: Claude Code (`.agents/skills`) + Cursor (`.cursor/skills`) install
- Agile lifecycle: `ship` and `retro` skills; `docs/agents/workflow.md`
- Sandcastle: lockfile-based install hook via `detect-package-manager.sh`
- Merged `security-audit` into `review` deep pass
- Script tests in `tests/bin/run-tests.sh`

## 0.1.0

- Initial ai-kit: workflow skills, book rules, Sandcastle templates, bootstrap
