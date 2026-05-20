# Changelog

## 1.1.1 — Claude Code skills discovery fix

**Bug fix**
- `bin/bootstrap-project.sh`: project bootstrap now also creates `.claude/skills/`
  symlinks. Claude Code (the CLI) reads skills from `.claude/skills/` and
  `~/.claude/skills/` — not from `.agents/skills/`. Before this fix, project
  skills were invisible to Claude Code unless symlinked manually.
- `bin/install-global.sh`: also symlinks into `~/.claude/skills/`. Collision-safe:
  refuses to clobber existing non-aikit entries (e.g. GSD skills); only
  re-links symlinks that already point into ai-kit.
- `bin/verify-setup.sh`: now checks `.claude/skills/` presence as a required
  Tier-A artefact (in addition to `.agents/skills/` and `.cursor/skills/`).
- `context/templates/CLAUDE.md.template`: documents `.claude/skills/` as the
  primary Claude Code skill path; `.agents/skills/` retained as legacy.
- Tests in `tests/bin/run-tests.sh` cover the new path across `--minimal`,
  `--link-all`, `--merge-skills`, and `--no-skills` modes.

**Migration**
- Existing projects on 1.1.0: re-run `bin/bootstrap-project.sh <project> --merge-skills`
  to populate `.claude/skills/`. Existing `.agents/skills/` and `.cursor/skills/`
  symlinks are preserved (merge mode is idempotent).
- Existing global install: re-run `bin/install-global.sh` to add `~/.claude/skills/`
  links. Will skip any name that conflicts with an existing non-aikit skill.

## 1.1.0 — public repo, eval harness, observability

**Repo hygiene**
- Public on GitHub at `yusufkaracaburun/ai-kit`; MIT licensed
- `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`
- `.github/ISSUE_TEMPLATE/{bug,skill-suggestion}.yml`, `pull_request_template.md`
- README badges + License & Provenance section

**CI + bash hardening**
- Test matrix expanded to ubuntu + macos
- shellcheck (severity: warning) and yamllint as a separate lint job
- Safe-expansion pattern in `bin/detect-tooling.sh` for bash 3.2 (macOS default)

**Skills**
- `grill-me`: full `## Process` + `DEEPENING.md` with 5 worked scenarios (PRD / ADR / design / migration / scope-cut)
- `handoff`: full `## Process`, template, what-NOT-to-include, redaction rules
- All 16 skills: uniform `## Usage logging (opt-in)` appendix wiring the `log-skill.sh` convention
- `retro`: reads `usage-stats.sh` to ground questions in observed behaviour
- 3 description tweaks to satisfy trigger-phrase check (qa, review, setup unaffected via `disable-model-invocation`)

**MCP**
- `context/templates/.cursor/mcp.json.template` baseline with commented filesystem/github/playwright servers
- `bin/lib/detect-lib.sh`: detects `.mcp.json` (Claude Code) alongside `.cursor/mcp.json` and `.vscode/mcp.json`
- `bin/bootstrap-project.sh --with-mcp`: opt-in copy of the baseline; skips if any mcp.json already exists
- `tests/fixtures/brownfield-claude-mcp` + assertions

**Eval harness**
- `tests/bin/eval-structure.sh`: 8 deterministic SKILL.md checks + per-fixture lint
- `tests/eval/prompts/{diagnose,tdd,ship,retro,to-prd}/<scenario>.md`: 5 starter fixtures
- `tests/eval/results/.gitkeep`: gitignored sink for manual rating notes
- `bin/eval-skill.sh`: dumps prompt + skill + rating template for manual scoring
- Hooked into `tests/bin/run-tests.sh` (CI fails on structural drift)
- `docs/eval.md`: structural vs behavioural layers, fixture authoring guide
- ADR-0002 explains the no-LLM-judge decision

**Observability (opt-in)**
- `bin/log-skill.sh`: appends JSONL events when `AI_KIT_USAGE=1`; no-op otherwise; never logs absolute paths, prompt content, or file content
- `bin/usage-stats.sh`: starts / completes / abandon% report, `--since=7d|30d|all`, `--json`
- `bin/usage-purge.sh`: wipes log with confirm or `--yes`
- README "What ai-kit logs locally" section; SECURITY.md captures the privacy contract
- CI regression: greps `curl|wget|/dev/tcp|nc` in usage scripts (must be empty)

**Docs**
- `docs/mental-model.md`: lifecycle diagram + which-skill-when table
- `docs/troubleshooting.md`: expanded FAQ; README links to it
- `docs/adr/0001-setup-modes.md` (4 modes not 6)
- `docs/adr/0002-skill-eval-approach.md` (no LLM judge)
- `docs/adr/0003-merge-security-audit-into-review.md` (v0.2 retro-doc)
- `docs/dogfood-portal.md` extended to 3 case studies (Nx, Laravel, Vite+React)

**Examples**
- `.examples/greenfield-nextjs/`: solo-both Tier A walkthrough
- `.examples/brownfield-laravel/`: coexistence with existing rules/MCP/skills
- `.examples/monorepo-nx/`: nested rules + dual MCP

**Tests**: 45 → 61 passing.

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
