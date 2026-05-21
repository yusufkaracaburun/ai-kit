# Changelog

## Unreleased

**Fix**
- **`ai-kit-mcp` wrapper — kills the absolute-path footgun in MCP client
  configs** (`bin/ai-kit-mcp`, `bin/install-global.sh`, `mcp/README.md`):
  - `mcp/README.md` previously told clone-install users to write
    `"args": ["/Users/<you>/.local/share/ai-kit/mcp/dist/server.js"]` —
    hardcoded absolute path that breaks the moment the user moves their
    clone or has a different home dir. JSON `args` aren't shell-expanded
    so `$AI_KIT_ROOT` or `~` don't work as a substitute.
  - New `bin/ai-kit-mcp` wrapper resolves the ai-kit root the same way
    the rest of ai-kit does (`$AI_KIT_ROOT` → `~/.config/ai-kit/root` →
    script-location walk), guards against missing build / missing
    node, then `exec node $AIKIT/mcp/dist/server.js`. `readlink -f`
    handles the case where the wrapper is invoked via a symlink (its
    own `bin/lib/` lookup would otherwise resolve to the symlink's
    parent dir).
  - `install-global.sh` symlinks `bin/ai-kit-mcp` into `~/.local/bin/`
    (XDG default, on PATH for most modern shells). Prints a clear note
    if `~/.local/bin` isn't on PATH. Idempotent like the other install
    passes; skips on non-aikit clobbers.
  - Result: MCP client config simplifies to `{ "command": "ai-kit-mcp" }`
    — no args, no absolute paths, no client edits when the clone moves.
  - 8 new regression tests: wrapper presence + executability, no
    `/Users/` hardcoding, sources `ai-kit-root.sh`, has both missing-build
    and missing-node guards, install-global creates the symlink,
    symlink resolves back to source.

**Docs**
- **Roadmap section 3 + mental-model refresh** (`docs/roadmap.md`,
  `docs/mental-model.md`):
  - `docs/roadmap.md` gains a new section "Primitives-uitbreiding"
    documenting the four landed PRs (architecture/glossary, subagents +
    slash commands, plugin, MCP) with status, motivation, and open
    follow-ups. Surfaces the trade-off behind v1 gaps (Cursor
    `.cursor/commands/` runtime verification, hook-in-plugin, npm
    publish, subagent source-of-truth, broader skill→subagent migration)
    so future passes pick them up without re-deriving context.
  - `docs/mental-model.md` updated from "16 skills" to 19 skills, with
    new "Subagents (Claude Code only)" and "Slash commands (IDE-native
    diagnostics)" tables. Links to the PR 0 architecture and glossary
    docs. The "which skill, when" table now covers checkpoint/resume
    and recommend-rules.

**Feature**
- **MCP server — `@yusufkaracaburun/ai-kit-mcp`** (new `mcp/` directory):
  - Node + TypeScript stdio MCP server that exposes ai-kit assets to
    any MCP-speaking host (Cline, Continue, Zed, Claude Desktop). Claude
    Code and Cursor users don't need this — they get skills via symlinks
    or the plugin.
  - Five read-only tools: `ai_kit_which { intent }`, `ai_kit_skill { name }`,
    `ai_kit_rule { name }`, `ai_kit_doctor {}`, `ai_kit_list { kind }`.
    Each shells out to existing `bin/*.sh` scripts via `execFile` (no
    shell → no injection), validated with zod (rejects path traversal
    at the schema boundary), 10s timeout, 1 MB output cap.
  - Resolves ai-kit root via the same chain as `bin/lib/ai-kit-root.sh`:
    `$AI_KIT_ROOT` env → `~/.config/ai-kit/root` → script-location walk.
    `mcp/src/resolve-root.ts` is the TS port.
  - Install paths: `npm install -g @yusufkaracaburun/ai-kit-mcp` (once
    published) OR `node /path/to/ai-kit/mcp/dist/server.js` from a clone.
    Both documented in `mcp/README.md`.
  - Tests via `node --test --import tsx`: handshake test spawns the
    server, sends JSON-RPC `initialize` + `tools/list`, asserts 5 tools.
    A second test calls `ai_kit_list` end-to-end; a third confirms zod
    rejects path-traversal inputs to `ai_kit_rule`. CI runs on Node 20
    and 22 via `.github/workflows/mcp.yml`.
  - `bin/sync-plugin-version.sh` extended: VERSION now stamps THREE
    locations (plugin.json, marketplace.json, mcp/package.json). `--check`
    reports any drift. `bin/release.sh` adds `mcp/package.json` to the
    release commit when present.
  - Intentionally NOT exposed (v1): tools that write files
    (`bootstrap-project.sh`, `emit-rules.sh`, `write-setup-marker.sh`),
    HTTP transport, project-cwd-dependent tools (`recommend-rules`).
    Reconsider in v2 with proper consent/auth.
  - 10 new shell regression tests covering source-tree presence,
    package version equality, gitignore correctness, 5-tool count, and
    no-shell-exec guard. 224 shell tests + 3 Node tests pass.

**Feature**
- **Claude Code plugin distribution** (`workflow/.claude-plugin/plugin.json`
  + `.claude-plugin/marketplace.json`):
  - Plugin manifest at `workflow/.claude-plugin/plugin.json` declaring
    `name: ai-kit`, derived from `VERSION`. Skills, agents, and commands
    are already at `workflow/{skills,agents,commands}/` — the plugin root
    is `workflow/` itself, no restructuring needed.
  - Self-hosted marketplace catalog at `.claude-plugin/marketplace.json`
    listing the ai-kit plugin with `source: "./workflow"`. Users add via
    `/plugin marketplace add yusufkaracaburun/ai-kit`, install with
    `/plugin install ai-kit@ai-kit`.
  - **Version-sync** (`bin/sync-plugin-version.sh`): one command stamps
    `VERSION` into both `plugin.json:version` and
    `marketplace.json:plugins[0].version`. `--check` mode exits non-zero
    on drift; called from `bin/release.sh` so every tagged release stays
    in lockstep automatically. Unicode-safe (`ensure_ascii=False`) — no
    em-dash escaping.
  - **Doctor** (`bin/ai-kit-doctor.sh`) gains a `Plugin install` section:
    reports manifest presence + VERSION equality, and warns when both
    the plugin install and symlink-install are active (stale-version
    risk).
  - **Docs**: new `docs/install-plugin.md` covers install / update /
    coexistence trade-offs and the namespace-prefixed skill IDs
    (`/ai-kit:setup`, `/ai-kit:ship`, etc). README adds the plugin
    install path as an alternative to the curl-installer.
  - **Not bundled in plugin**: the PostToolUse skill-logging hook
    (opt-in via `AI_KIT_USAGE=1`, needs the bin/hooks script) and the
    rule emitter (needs write-access to the project repo). Symlink-install
    users keep both. Documented as an intentional gap in
    `docs/install-plugin.md`.
  - 13 new regression tests covering manifest validity, source path,
    marketplace owner shape, three-way version equality, and
    `sync-plugin-version.sh --check` drift-detection.

**Feature**
- **Claude Code subagents — `aikit-explore` + `aikit-reviewer`** (new
  `workflow/agents/`):
  - `aikit-explore` is a read-only codebase exploration subagent. Tools:
    Read, Grep, Glob, Bash. Bounded output (≤300 lines), structured return
    (Summary / Findings / Files inspected / Confidence). Spawn from any
    skill that needs cross-file sweeps without polluting main context.
  - `aikit-reviewer` is a pre-merge code review subagent. Same tool set.
    Returns a strict markdown report (Scope / Blockers / Security /
    Suggestions / Verdict). The `review` skill now delegates to it on
    Claude Code; Cursor and other hosts fall back to the inline checklist
    (single source of truth).
  - `bin/install-global.sh` refactored: shared `install_dir_to <src>
    <target>` (skills + agents) and new `install_files_to <src> <target>`
    (slash commands, file-level not dir-level). Both refuse to clobber
    existing non-aikit entries.
  - `bin/bootstrap-project.sh` learns `merge_agents` + `merge_commands`,
    plus `--no-agents` / `--no-commands` opt-outs. Skills, agents, and
    commands are now independently controllable at bootstrap.
- **Claude Code + Cursor slash commands** (`workflow/commands/`):
  - Five thin wrappers around `bin/ai-kit-*.sh` for IDE-native UX:
    `/aikit-doctor`, `/aikit-which`, `/aikit-status`, `/aikit-no-globals`,
    `/aikit-upgrade`. Each runs the underlying script via `!`-prefix
    (deterministic, output piped to the model), then instructs the model
    to summarise blockers and suggest the exact next-step command.
  - `install-global.sh` mirrors to both `~/.claude/commands/` and
    `~/.cursor/commands/`; bootstrap mirrors to project `.claude/commands/`
    and `.cursor/commands/`. Cursor command-discovery is opportunistic —
    if the host ignores them, no harm done.
  - 34 new regression tests covering: subagent file presence + frontmatter,
    slash command file presence + frontmatter, bootstrap-time linking of
    agents and commands, `--no-agents` / `--no-commands` opt-outs, review
    skill's delegation pattern.

**Docs**
- **Architecture + glossary + primitives decision tree** (`docs/architecture.md`,
  `docs/glossary.md`, `docs/primitives.md`):
  - `architecture.md` lays out the three-layer model (source → distribution →
    host), maps every primitive type to its source path / distribution channel /
    host directory, and documents the two coherence rules (symlink-not-copy,
    emitter pattern). Forward-references planned PR 1-3 primitives (subagents,
    slash commands, plugin, MCP server) so future contributors land them in
    the right place.
  - `glossary.md` defines every recurring term alphabetically and explicitly
    aliases conflicting names (`agent` host-sense vs subagent-sense, `command`
    vs slash command). Single-source for terminology across skills and docs.
  - `primitives.md` is a decision tree — "I want to add X" → hook / slash
    command / skill / subagent / rule / MCP tool / bin script / template — with
    six worked examples and six anti-patterns. Constraint test + host-reach
    test as the two questions to ask.
  - README adds links to all three docs. Skill-count language in
    `bin/ai-kit-which.sh` switched to tense-agnostic ("every shipped skill")
    to prevent future drift (was "16", now matches the 19 dirs in
    `workflow/skills/`). Same fix in `README.md` structure block.

**Feature**
- **Claude Code hook: auto-log Skill invocations** (`bin/hooks/post-skill-log.sh`):
  - New `PostToolUse` hook wired in committed `.claude/settings.json`
    (matcher `^Skill$`). Reads the hook JSON payload from stdin, extracts
    `tool_input.skill`, and calls `log-skill.sh <skill> done`. Closes the
    long-standing gap where `log-skill.sh` existed but no skill called it,
    leaving `usage.jsonl` empty even with `AI_KIT_USAGE=1` set.
  - Triple opt-in: hook registered, `AI_KIT_USAGE=1` in env, tool name was
    `Skill`. The wrapper itself is silent — `set -uo pipefail` (no `errexit`)
    plus per-step `2>/dev/null` ensures a malformed payload or missing
    `jq`/`python3` can never break a Claude Code session.
  - JSON parsing: `jq` preferred, `python3` fallback. Defense-in-depth
    `tool_name` check against the payload in case of matcher misconfig.
  - 8 new regression tests in `tests/bin/run-tests.sh` covering opt-out,
    happy path, non-Skill tools, empty stdin, missing skill field. The
    privacy net-call grep now also covers the hook script.
- **Agent-agnostic rule emission** (`bin/emit-rules.sh`):
  - Replaces the removed Cursor-only `.mdc` generator with a pluggable
    emit layer. `detect_agents()` (in `bin/lib/detect-lib.sh`) identifies
    Cursor, Claude Code, Aider, Cline, Continue, Cody by config markers.
  - Per-agent emitters in `bin/lib/emitters/`: `cursor.sh` (`.mdc` with
    frontmatter), `claude-code.sh` (`.claude/rules/<name>.md` with
    generation marker), `generic.sh` (idempotent `docs/agents/active-rules.md`
    index, the universal fallback for any tool reading `AGENTS.md`).
  - Shared helpers in `bin/lib/emitter-lib.sh` parse rule frontmatter
    (`_emitter_extract_meta`, `_emitter_extract_list`, `_emitter_strip_frontmatter`).
  - Each emitted file carries a `Generated by ai-kit @ <version>` marker
    pointing back to `standards/rules/<name>.mini.md` — staleness is now
    detectable, not silent. Re-emit is idempotent (overwrites cleanly).
  - `bootstrap-project.sh` calls `emit-rules.sh` after skill linking; opt
    out with `--no-rules`.
- **Rule frontmatter schema** on all 8 canonical rules (`standards/rules/*.mini.md`,
  `*.nano.md`): `universal`, `default_mode`, `weight`, `applies_to.{frameworks,
  architectures}`, `repo_age_min_years`. Drives both emit selection (default
  emits `universal: true` only) and the recommender.
- **Project-aware rule recommender** (`bin/recommend-rules.sh`,
  `bin/lib/recommend-lib.sh`):
  - Scores every canonical rule against detect-tooling output (frameworks +
    architectures) and `git log` repo age. Returns sorted name/score/weight/
    reason rows; `--json` for downstream consumption.
  - New `recommend-rules` skill (`workflow/skills/recommend-rules/SKILL.md`):
    runs the scorer, presents tiered results (strong/moderate/filtered),
    optionally layers a focused web-search step for stack-specific community
    rules (Laravel Boost, Next.js packs, etc.) with preview-before-vendor
    trust model. Vendored external rules land in
    `standards/rules/external/<slug>.mini.md` with provenance frontmatter
    (`source_url`, `license`, `pinned_sha`, `vendored_at`).
  - Skill count: 18 → 19.
- Eval fixture for the new skill: `tests/eval/prompts/recommend-rules/laravel-mature.md`.
- Test coverage extended in `tests/bin/run-tests.sh`:
  - `=== emit-rules ===` block: cursor + claude file presence, generation
    marker, idempotent re-emit, `--rules` + `--agents` filtering, `--list`
    enumerates all 8 rules.
  - `=== recommend-rules ===` block: JSON shape, score is int, results
    sorted desc, universal rules always surfaced.
  - `--no-rules` bootstrap path validated.
- Roadmap items #1 and #2 from `docs/roadmap.md` are now landed (skeleton +
  Cursor/Claude Code/generic emitters). Aider/Cline/Continue/Cody emitters
  remain stubs (`bin/emit-rules.sh` prints `skip:<agent>`) — follow-up work.

**Removed**
- Cursor-specific rule generation in `bootstrap-project.sh` (`.cursor/rules/*.mdc`):
  no longer creates `ai-kit.mdc`, the seven book-rule `.mdc` shims, or
  `pragmatic-baseline.mdc`. `standards/rules/*.mini.md` remain the source of
  truth — skills read them on-demand. `verify-setup.sh` no longer asserts
  `ai-kit.mdc`. Legacy installs: leftover `.mdc` files are detected and
  classified (see `_aikit_rule_names` in `detect-lib.sh`) so users can remove
  them manually. Templated `.cursor/rules/ai-kit.mdc` deleted from
  `context/templates/`. Step toward an agent-agnostic ai-kit — Cursor stops
  being a privileged target for rule emission.

**Feature**
- Two new skills for session continuity, first-class in ai-kit (16 → 18):
  - **`checkpoint`** — saves a session-continuation memo to the auto-memory
    folder before `/clear`, `/compact`, a long break, or end of session.
    Includes self-check rubric (memo must have `## Where we are` +
    `## Open / next`, ≥3 bullets, ≥1 concrete reference), auto-flag for
    `[stale]` entries in `MEMORY.md` when their branch is gone, edge-case
    handling for non-git projects and slug collisions, and an explicit
    "other skills in this space" routing block pointing at `/handoff`
    (cross-machine) and `/gsd-pause-work` (GSD projects).
  - **`resume`** — companion that finds the most recent checkpoint, summarises
    it in five lines, proposes one concrete first action, and waits for user
    confirmation. Never silently runs destructive ops. Routes to
    `/gsd-resume-work` for GSD projects.
  - Each has a fixture + golden + machine-checkable rubric. README's agile
    lifecycle table gains a Session-continuity row.
  - `eval-structure.sh`: recognises the `allowed-tools` Claude Code field
    and skips placeholder-template links (`[link](<path>)`).
- `bin/ai-kit-which.sh`: skill picker. Takes free-text intent and ranks the
  16 skills by keyword overlap against each `SKILL.md` description, surfacing
  top-3 with rationale. Also supports `--list` (catalog) and `--explain
  <skill>` (full dump). No LLM, no deps — pure bash + awk scoring. Recommended
  use: `ai-kit-which.sh "I want to write a PRD"` → `/to-prd` at rank 1.
- Golden-output evals for `to-prd`, `tdd`, `ship`. Hand-written ideal responses
  at `tests/eval/goldens/<skill>/<scenario>.md` carry a structured rubric
  (required headings/keywords/phrases, forbidden keywords, line bounds).
  New runner `bin/eval-golden.sh` validates goldens against their own rubric
  and can score a real model response against it. Purely deterministic —
  no API calls, no runtime deps added. CI runs `--validate-all` on every
  push, catching drift between rubric and golden.
- `tests/eval/README.md` documents the two-layer eval system (structural
  checks + golden rubric) and the manual paste-and-score flow.
- `install.sh` at repo root: one-line curl installer. Clones ai-kit into
  `~/.local/share/ai-kit` (configurable) and runs `bin/install-global.sh`
  by default. Flags: `--dir`, `--repo`, `--branch`, `--ref`, `--no-global`,
  `--update`, `--quiet`. All flags also work as `AI_KIT_*` env vars for
  curl-pipe use. Idempotent: rerun detects existing clones; refuses to
  clobber non-aikit directories.
- README quick-start leads with the one-liner; manual install moved to
  a collapsed section.
- Tests: 7 new assertions covering clone, idempotent rerun, clobber
  refusal, `--no-global`, unknown-flag exit code, and help output.
- CI: `install.sh` added to shellcheck scope.

## 1.2.0 — opt-in automation recommender handoff

**Feature**
- `/setup` Tier B branch 10: propose-but-defer the `claude-automation-recommender`
  skill (from the `claude-code-setup` plugin). ai-kit surfaces the option once,
  records the user's choice in `.ai-kit-setup`, and never invokes the external
  skill. Pattern mirrors `diagnose` → `/improve-codebase-architecture` handoff.
- `bin/write-setup-marker.sh`: new `--automation-recommender=skipped|deferred|completed`
  flag; persisted under `branches.automation_recommender`.

**Backward compatibility**
- Existing markers without the key remain valid; `verify-setup.sh --strict`
  ignores missing keys (lenient `.get(...)` reads). No migration required.

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
