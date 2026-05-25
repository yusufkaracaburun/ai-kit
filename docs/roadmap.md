# Roadmap

Forward-looking work. Not commitments — directions. ADRs land here once decided.

## 1. Agent-agnostic refactor

> **Partly superseded by section 4.** The Aider / Cline / Continue / Cody emitters were removed 2026-05-22 — `emit-rules.sh` now targets Cursor + Claude Code only. This section is kept as a historical record.

**Status:** **landed** 2026-05-22. All six emitters (Cursor, Claude Code, generic, Aider, Cline, Continue, Cody) work; bootstrap wires it up; tests cover each. Only the legacy-install migration guide (task below) is still open.

**Problem.** ai-kit currently treats Cursor as a privileged target: book rules are emitted as `.mdc` shims with Cursor frontmatter, `AGENTS.md` references `.cursor/rules/`, and `_aikit_rule_names()` knows Cursor file conventions. Other agents (Claude Code, Aider, Cline, Continue, Cody, etc.) only get skills via symlink — no rule layer.

**Direction.** Treat `standards/rules/*.mini.md` as the canonical agent-agnostic source. Add a per-agent **emit layer** that translates the canonical markdown into whatever the target tool understands:

| Agent | Rule format | Auto-load mechanism |
| ----- | ----------- | ------------------- |
| Cursor | `.cursor/rules/*.mdc` with frontmatter | `alwaysApply: true/false` |
| Claude Code | `.claude/skills/*` with frontmatter, or hooks | skill-discovery + slash invocation |
| Aider | `.aider.conf.yml` `read:` list | always-on read |
| Cline | `.clinerules` | always-on read |
| Continue | `~/.continue/config.json` slash blocks | tagged context |
| Cody | `.sourcegraph/cody/*.md` | context-fetcher |
| Generic | `AGENTS.md` references | on-demand read |

**Sketch of structure.**

```
standards/rules/                   ← canonical (today)
└── *.mini.md, *.nano.md

bin/emit-rules.sh                  ← NEW: takes detected agents + rule names → writes to target
  └── lib/emitters/
        ├── cursor.sh              ← .mdc with frontmatter
        ├── claude-code.sh         ← skill or hook
        ├── aider.sh
        └── …
```

`bootstrap-project.sh` calls `emit-rules.sh` per detected agent (Cursor present → emit Cursor format; Aider present → emit Aider format; both → emit both). Migration: legacy `.cursor/rules/*.mdc` keep working because Cursor reads them as-is — emit overwrites idempotently when ai-kit version bumps.

**Tasks.**
- [x] `detect_agents()` in `bin/lib/detect-lib.sh` (cursor, claude-code, aider, cline, continue, cody).
- [x] `bin/lib/emitters/` per agent — all six implemented (cursor, claude-code, generic, aider, cline, continue, cody).
- [x] `bin/emit-rules.sh <project> [--rules X,Y] [--agents A,B] [--mode] [--dry-run] [--list]`.
- [x] `bootstrap-project.sh` wires `emit-rules.sh` after skill linking; `--no-rules` to opt out.
- [x] Tests in `tests/bin/run-tests.sh` cover emit + idempotency + filtering.
- [x] `AGENTS.md.template` no longer mentions Cursor-specific `.cursor/rules/`; agent-agnostic phrasing.
- [x] emeq/admin migrated by hand (commit `51accea` "chore: drop ai-kit Cursor rule shims").
- [x] Stub emitters finished — `aider.sh`, `cline.sh`, `continue.sh`, `cody.sh` (2026-05-22). Each writes per-rule files to the agent's conventional rules dir; a legacy single-file `.clinerules` is skipped (with a reason), not clobbered.
- [x] Migration guide for pre-2.0 legacy installs — `docs/troubleshooting.md` "Migrating from a pre-2.0 install" (2026-05-22, closes #10).

---

## 2. Project-aware rule recommendation (with optional web search)

**Status:** **landed** 2026-05-22. Canonical scorer + frontmatter schema + skill scaffolding done. The vendoring flow is now exercised end-to-end — `standards/rules/external/laravel-php-83.mini.md` is the first web-vendored rule, pinned by SHA. `/ai:recommend-rules` is wired into `/ai:setup` as Tier B Branch 12. Only web-search caching remains open.

**Problem.** Today, bootstrap *used to* emit all 7-9 ai-kit book rules to every project regardless of stack. A Laravel monolith and a React+Vite SPA got identical rules. That's noise — refactoring/legacy-code rules are valuable for a 10-year-old codebase, less so for a greenfield prototype. Worse: ai-kit has no awareness of *stack-specific* community rules that already exist (Laravel Boost rules, Next.js conventions, Rails idioms, Django patterns).

**Direction.** A new step in `/ai:setup` (or standalone `/ai:recommend-rules` skill) that:

1. **Reads detection.** `detect-tooling.sh --json` → frameworks, package manager, language, architecture, repo age (commit count / first-commit date).
2. **Scores canonical rules.** Mapping table: `legacy-code` → high score for repos with >2y history; `ddd-distilled` → high for backend-with-domain-folders; `release-it` → high for repos with deployment config; `aposd` → universal; `pragmatic-baseline` → universal. Filter out low-score rules.
3. **Searches stack-specific rules.** Web search for community-curated rule sets matching detected stack: `"laravel-boost cursor rules"`, `"nextjs app-router rules markdown"`, `"rails cursor rules awesome"`. Surface top candidates by GitHub stars / last-update / license.
4. **Proposes.** Show user a ranked list: `[canonical, score, reason] + [external, source, summary]`. User picks per-item: install / skip / preview-first.
5. **Emits via the agent-agnostic emitter from item #1.**

**Sketch.**

```bash
$ /ai:setup
…
Detected: Laravel 11, Inertia, Vue 3, PHP 8.3, Composer, MySQL.
Repo age: 4 years (1842 commits).

Recommending rules:

[canonical — high relevance]
  ✓ legacy-code         4y repo with significant size → seam-finding matters
  ✓ ddd-distilled       app/Domain/ + app/Application/ detected
  ✓ release-it          .github/workflows/deploy.yml present
  ✓ git-hygiene         universal
  ✓ context-discipline  universal
  ○ aposd               universal — keep?
  ○ refactoring         universal — keep?

[canonical — low relevance]
  ✗ pragmatic-baseline  rejected: opinion-light, conflicts with aposd

[external — found on web]
  ? laravel-boost/rules       github.com/laravel/boost • 1.2k★ • updated 2d ago
                              "Laravel-specific Cursor rules from Laravel team"
  ? inertia-best-practices    github.com/some/repo • 340★ • updated 3w ago

Install canonical (y/n/preview each)? Install external (per-item)?
```

**Open design questions.**
- Where does the "stack → rule score" mapping live? Pure heuristic in `bin/lib/recommend-lib.sh`, or in `standards/rules/<name>.mini.md` frontmatter? (Lean: frontmatter — keeps the rule self-describing.)
- Web search dependency: which agent does the search? Probably done by Claude inside the `/ai:recommend-rules` skill, not a bash script — keeps ai-kit dependency-free.
- Trust model for external rules: ai-kit shouldn't auto-install arbitrary markdown from the internet. Always preview-then-confirm, never silently fetch + emit.
- Caching / pinning: do we vendor external rules into `standards/rules/external/` after first install, or keep them as live fetches? (Lean: vendor — reproducibility, offline-friendly, version pinning.)

**Tasks (rough order).**
- [x] Frontmatter schema on all 8 canonical rules: `universal`, `default_mode`, `weight`, `applies_to.{frameworks,architectures}`, `repo_age_min_years`.
- [x] `bin/lib/recommend-lib.sh` — bash + tiny inline python for JSON parsing. Scores against detect-tooling output + repo age.
- [x] `bin/recommend-rules.sh` CLI with `--json`.
- [x] `workflow/skills/recommend-rules/SKILL.md` — Phase 1 (canonical scoring) + Phase 2 (web search) + Phase 3 (emit) flow with trust model.
- [x] Vendoring convention documented in the skill (provenance frontmatter, pin-by-SHA, preview-before-write).
- [x] Wired `/ai:recommend-rules` into `/ai:setup` as Tier B Branch 12 (2026-05-22); the choice is recorded in the marker via `write-setup-marker.sh --rule-recommendation`.
- [x] First external rule vendored — `standards/rules/external/laravel-php-83.mini.md` from `PatrickJS/awesome-cursorrules` (CC0-1.0), pinned to SHA `4467ad4` (2026-05-22). Validates the Phase 2 → Phase 3 trust flow.
- [x] **Cache web-search results.** (#11, 2026-05-23) `bin/recommend-rules-cache.sh` is a fingerprint-keyed cache for Phase 2 community-rule discovery. Cache key is a sha256 over sorted detected frameworks + frontend/backend architecture; default TTL 7 days; lives under `${XDG_CACHE_HOME:-~/.cache}/ai-kit/recommend-rules/`. Subcommands: `key`, `read`, `write`, `path`, `clear`, with `--ttl N` and `--no-cache` flags. The skill calls `read` before searching and `write` after, bypasses with `--no-cache` on user refresh. 13 regression tests cover hit/miss/TTL/refresh/invalid-JSON-rejection.

---

## 3. Primitives-uitbreiding (subagents, slash commands, plugin, MCP)

> **Partly superseded by section 4.** The MCP server (PR 3) was removed 2026-05-22. This section is kept as a historical record.

**Status:** **landed** 2026-05-21. PR 0 through PR 3 shipped on master. Triggered by an inventory against the "12 Must-Use Claude Code Features" listicle — gap analysis showed ai-kit was using 4 of the 7 actionable primitives (CLAUDE.md, Rules, Skills, Hooks); this round added the other 4 actionable ones (Subagents, Slash commands, Plugin, MCP). The 3 N/A items (Permissions, Plan Mode, Voice, Rewind) are Claude Code built-ins.

**Direction.** Claude Code voorop, Cursor pariteit waar haalbaar. PR 0 ships an architecture doc + glossary + decision-tree as anti-drift foundation BEFORE adding primitives, so future contributors know which primitive type fits which problem (see `docs/architecture.md`, `docs/glossary.md`, `docs/primitives.md`).

**Landed.**
- [x] **PR 0** — `docs/architecture.md` (three-layer model: source → distribution → host, per-primitive routing table), `docs/glossary.md` (alphabetical terms with explicit aliases), `docs/primitives.md` (decision tree + worked examples + anti-patterns). Skill-count drift fixed (was "16" in `ai-kit-which.sh`, now tense-agnostic).
- [x] **PR 1** — Two subagents (`workflow/agents/explore`, `workflow/agents/reviewer`) with the inline-fallback delegation pattern. Five slash commands (`workflow/commands/ai:{doctor,which,status,no-globals,upgrade}.md`). `install-global.sh` refactored to `install_dir_to` + `install_files_to` (skills + agents + commands). `bootstrap-project.sh` learns `merge_agents` + `merge_commands` with `--no-agents` / `--no-commands` opt-outs.
- [x] **PR 2** — Plugin distribution: `workflow/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`. Users install via `/plugin marketplace add yusufkaracaburun/ai-kit` then `/plugin install ai-kit@ai-kit`. `bin/sync-plugin-version.sh` keeps VERSION / plugin / marketplace / mcp/package.json in lockstep; called from `bin/release.sh` on every tag. Doctor warns on plugin+symlink co-existence. `docs/install-plugin.md` walks through the three install paths and trade-offs.
- [x] **PR 3** — MCP server (`mcp/`): Node + TypeScript, stdio transport, 5 read-only tools (`ai_kit_which`, `ai_kit_skill`, `ai_kit_rule`, `ai_kit_doctor`, `ai_kit_list`). Security: `execFile` not `exec`, zod-validated inputs, 10s timeout, 1 MB output cap, stderr-only logging. CI matrix Node 20 + 22. Reaches Cline / Continue / Zed / Claude Desktop users that the symlink-install and plugin path don't cover.

**Open follow-ups (PR 4 territory — not blocking).**
- [x] **Hook in the plugin.** (#8, 2026-05-23) Plugin now ships
  `workflow/hooks/post-skill-log.sh` + `workflow/hooks/log-skill.sh` +
  `workflow/hooks/hooks.json` (PostToolUse `^Skill$` matcher pointing at
  `${CLAUDE_PLUGIN_ROOT}/hooks/post-skill-log.sh`). The hook script does
  dual-location resolution — finds its sibling `log-skill.sh` in
  `workflow/hooks/` for plugin installs, falls back to `bin/log-skill.sh`
  for the symlink-source install. `bin/sync-plugin-hooks.sh` keeps the
  bundled copies byte-identical to the `bin/` source-of-truth;
  `--check` mode fails CI on drift; wired into `bin/release.sh`. Opt-in
  is unchanged: `AI_KIT_USAGE=1` in the env. Tests cover both layouts
  + the drift round-trip.
- [x] **Subagent source-of-truth.** (#12, 2026-05-22) `bin/emit-agents.sh` regenerates a marked region of `workflow/agents/*/AGENT.md` from named `## ` sections of the companion `SKILL.md`. `reviewer` pulls `Security deep pass` + `Output format` from `review`. CI `--check` mode fails the build on drift. Marker-region injection chosen over full generation — agents keep bespoke framing (Contract, Inputs, What-not-to-do).
- [x] **Migrate more skills to subagent delegation.** (#3, 2026-05-22) Four skills gained a `## Run mode` block with inline fallback. `qa` delegates the full QA pass to a new paired `qa-runner` subagent (single-sources `Tiers` + `Output` from the skill via `emit-agents.sh`). `diagnose`, `to-issues`, and `improve-codebase-architecture` delegate their codebase walk to the existing `explore` subagent — the last swapped off the generic `Explore`. A bespoke subagent each was rejected: the other three only do codebase reads, which `explore` already covers.
- [x] **`mental-model.md` refresh.** Landed in PR 4 — now documents 19 skills with the matching table, plus dedicated subagent and slash-command tables linking `architecture.md` / `glossary.md` / `primitives.md`.
- [x] **MCP server: published to npm.** (#4, 2026-05-22) `npm install -g @yusufkaracaburun/ai-kit-mcp`. package.json hardened (`publishConfig.access=public`, `prepublishOnly` clean+build+test, repository object + `directory`). Tag-gated CI publish: `.github/workflows/mcp-publish.yml` publishes on `v*` push, version-guarded against the tag.
- [x] **MCP server + non-CC/Cursor emitters removed.** (2026-05-22) Superseded by section 4 — ai-kit scoped to Claude Code + Cursor.

---

## 4. Scope reduction — Claude Code + Cursor only

**Status:** **landed** 2026-05-22. See [ADR-0006](adr/0006-scope-claude-code-cursor-only.md).

Sections 1 and 3 above built multi-host reach: rule emitters for Aider, Cline,
Continue, and Cody, and an MCP server for Cline / Continue / Zed / Claude
Desktop. In practice ai-kit is developed and used only on Claude Code and
Cursor, and the multi-host surface cost more than it returned — extra CI, an
npm package, doc surface, and a test matrix for hosts nobody here runs.

**Removed.**
- `mcp/` — the entire MCP server (Node + TypeScript, 5 tools) and its CI
  (`mcp.yml`, `mcp-publish.yml`). The `@yusufkaracaburun/ai-kit-mcp` npm
  package has been removed from npm.
- `bin/lib/emitters/{aider,cline,cody,continue}.sh` — the four non-CC/Cursor
  rule emitters. `emit-rules.sh` now dispatches to `cursor`, `claude-code`,
  and `generic` (the always-on rule index) only.
- `bin/ai-kit-mcp` wrapper and its `install-global.sh` symlink step.

**Kept.** Cursor and Claude Code emitters; the `generic` emitter (it maintains
the canonical `docs/agents/active-rules.md` index — not a host); user-project
MCP detection in `detect-tooling.sh` / `detect-lib.sh` (a Cursor project can
still run its own MCP servers); `bootstrap --with-mcp` (seeds `.cursor/mcp.json`).

The historical "landed" entries in sections 1 and 3 are kept intact as a
record — they describe what was shipped, then deliberately removed here.

---

## What's next

The subagent emitter is in place, four more skills now delegate to subagents,
and ai-kit has been scoped down to Claude Code + Cursor (section 4). Remaining,
in priority order:

1. **Web-search caching** for `/ai:recommend-rules` — landed 2026-05-23 (#11).
2. **Hook in the plugin** — landed 2026-05-23 (#8).
3. **Standalone plugin marketplace repo** — landed 2026-05-23 (#9).
   `yusufkaracaburun/marketplace` is the new catalog
   (https://github.com/yusufkaracaburun/marketplace). The in-repo
   `.claude-plugin/marketplace.json` is deleted; legacy install path
   no longer works. Breaking-change note in CHANGELOG. Future plugins
   register against the new catalog instead of needing their own
   marketplace.
4. **New skill + command `/ai:followup`** — landed 2026-05-23 (#16).
   One-shot defer capture: takes a one-line lead, opens a GitHub issue
   in house style, and appends a paragraph to `docs/roadmap.md`
   referencing the new issue. Replaces the per-project memory file
   `feedback_followup_default.md` with a cross-project skill that ships
   via the plugin. Decisions baked in: default label `enhancement`
   (override with `--label`), target section is the last `## What's
   next`, local-only mode appends the roadmap entry when `gh` is
   unavailable.
5. **Stack → MCP / hook recommendations** — landed 2026-05-23 (#14).
   `standards/external/{mcp-servers,hooks-patterns}.json` vendor the
   distilled signal tables from
   `anthropics/claude-plugins-official @ claude-code-setup/skills/claude-automation-recommender`
   (Apache-2.0, pinned SHA `3449c10c`). `bin/recommend-tools.sh` scores
   them against `detect-tooling.sh` output and file presence; the
   `recommend-tools` skill surfaces the ranked list with the same
   trust model as `/ai:recommend-rules` (never auto-install, never
   write `.claude/settings.json` without per-hook approval). Verdict
   via `/should-i-use` 2026-05-23 was **adopt-as-pattern** — the
   mapping tables, not the upstream skill itself, were the reusable
   artifact.
6. **Spike: autonomous-loop variant of `tdd`** — landed
   2026-05-23 (#17). See
   [docs/spikes/ai:autonomous-ralph.md](spikes/ai:autonomous-ralph.md).
   Verdict: ship as a **sibling skill** (`autonomous`), not a
   flag on existing skills and not a separate plugin. **Complementary,
   not competing** with `/loop` — `/loop` is the scheduler,
   `autonomous` is the worker (one issue per fire, exits clean).
   Draft skill landed at `workflow/skills/autonomous/SKILL.md`
   with `dry-run` as default mode, explicit stop conditions (TDD cap,
   review blockers, security ≥ high, git conflicts), and
   `.ai-kit/autonomous/progress.txt` as cold-start state. **Not wired
   into `setup`** — opt-in, hand-installed during validation
   period. Promotion from spike → released gated on first successful
   real-queue drain (currently 0 issues labeled `ready-for-agent`).
7. **Brainstorm: second plugin under `yusufkaracaburun/marketplace`** (#15).
   Parking lot for picking plugin #2 now that the standalone marketplace
   is live (#9). Marketplace shape only pays off at N ≥ 2. Candidate
   seeds: `emeq-kit` (emeq-specific lifecycle layer — Naschool / Snelstart
   / Mollie templates), `spec-kit` (PRD/ADR authoring subset of gsd-*),
   `browser-qa-kit` (Playwright/MCP QA standalone), `graphify-kit`
   (graphify + caveman + llm-wiki bundle). Exit criterion: pick one,
   decide fork-vs-fresh-start, open implementation issue against the new
   repo.
8. **Stack-aware tool recommendations during setup** (#19) — `/ai:setup`
   today configures rules + skills but does not proactively *propose
   companion tools* tied to the detected stack. `/ai:recommend-tools`
   (#14) is standalone and limited to MCP servers + Claude Code hooks;
   broader categories — vector stores / RAG (Qdrant, pgvector, Chroma,
   Weaviate), observability (Sentry, OpenTelemetry), dev tooling
   (linters, formatters, runtime managers), CLI helpers, and AI agent
   memory (Mem0, Letta, Zep) — get no nudge during setup. Two-part
   delivery: (a) broaden the signal tables under `standards/external/`
   to cover the missing categories, (b) wire `/ai:recommend-tools`
   into `/ai:setup` as a Tier B branch parallel to rule
   recommendations. Trust model unchanged — preview-then-confirm,
   never auto-install. Gap surfaced by `/should-i-use` Qdrant
   2026-05-23 — the verdict on Qdrant itself was **Ignore** (wrong
   category for the meta-tool), but the downstream-project advisory
   layer is missing entirely.
9. **Deploy / self-host PaaS advisory** (#20) — sibling of #8 for the
   deploy category. Detect server-shaped projects (`Dockerfile` +
   `docker-compose.yml`, no `vercel.json` / `netlify.toml` /
   `wrangler.toml` / serverless markers) and surface self-hosted PaaS
   options — Coolify (55k★, AGPL-3.0), Dokku, Caprover, Kamal — with
   the same preview-then-confirm trust model. Split from #19 because
   the deploy decision has a sharper either/or shape than the additive
   vector-DB / observability buckets, and each PaaS needs its own
   `/should-i-use` pass before vendoring signal tables. Gap surfaced
   by `/should-i-use` Coolify 2026-05-23 — Coolify itself = **Ignore**
   for ai-kit-the-repo (wrong category + AGPL-3.0 incompatible with
   MIT), but the downstream-project deploy advisory is missing.
10. **Research OpenHands runtime patterns before promoting
    `autonomous` spike** (#21) — research-arc input for closing
    the three contract gaps the spike walkthrough (#18) flagged
    (precondition checks, per-project `AI_KIT_ROOT` pinning, merge-
    policy detection). OpenHands (73.2k★) is a mature autonomous
    engineering agent with production-grade solutions for sandboxed
    per-task runtimes, queue selection, long-running iteration, and
    persistent state. Read their source, map each finding back to one
    of the spike's gaps, decide adopt-as-pattern / adopt-modified /
    reject per pattern. Output: new `Research input: OpenHands patterns`
    section in `docs/spikes/ai:autonomous-ralph.md` + updated
    contract in `workflow/skills/autonomous/SKILL.md`. Gap
    surfaced by `/should-i-use` OpenHands 2026-05-23 — OpenHands itself
    = **Ignore** as host target (ADR-0006 scopes ai-kit to Claude Code
    + Cursor) but **Adopt-as-pattern** for spike-research input.
11. **Vetting criteria for `standards/external/` catalog entries** (#22)
    — **landed** 2026-05-23 (commit `ed09f44`). `standards/external/VETTING.md`
    codifies the seven-criteria bar; existing entries retroactively audited
    (mcp-servers.json batch, hooks-patterns.json batch, laravel-php-83 rule
    all ADD; claude-mem REVISIT, deferred to AI-memory category). Re-audit
    cadence: on every new addition, annually, on any /should-i-use finding.
    Original entry kept below for traceability:

    Define a one-page
    `standards/external/VETTING.md` codifying the bar a candidate must
    clear before being added to any catalog: storage/data-shape parity
    with marketing, benchmark integrity (no "teaching to the test"),
    marketing-vs-code parity audit, license compatibility (MIT or
    HTTP/MCP-client-only), category-appropriate maturity (entity
    resolution, sandboxing, schema versioning), data-locality
    disclosure, provenance pin-by-SHA. Re-audit existing entries
    against the criteria once written. Surfaced by `/should-i-use`
    MemPalace 2026-05-23 — verdict was **Ignore** as catalog entry
    (3 documented false README claims) but **Adopt-as-pattern** for
    the underlying evaluation finding (verbatim-storage often beats
    LLM-extracted summaries on retrieval benchmarks).
12. **Refine llm-wiki glue with tight-linking rule + Obsidian viewer
    pointer** (#23) — **landed** 2026-05-23 (commit `e18236c`).
    Tightened the linking guidance in `wiki-schema.md` to Rusev's
    constraint (only link where understanding A genuinely changes how
    you see B; three meaningful cross-references beat fifteen weak
    ones). Added a "Viewers" section to the companion's `README.md`
    noting the layout is Obsidian-compatible out of the box and
    pointing at the graph view + Copilot plugin (mobile/tablet LLM
    querying) + Web Clipper as the most polished viewer stack —
    without making Obsidian a dependency. Surfaced by `/should-i-use`
    Rusev 2026-05-23.
13. **Surface context7 more prominently in recommend-tools** (#24)
    — small refinement to the recommend-tools companion catalog.
    `context7` is in `standards/external/mcp-servers.json` but its
    `signals` block matches a narrow curated framework list
    (react/vue/angular/nextjs/nuxt/svelte/express/fastify/fastapi/
    django/rails/laravel/spring) + a few LLM-SDK deps — so bash
    tooling, Go services, Rust CLIs, Phoenix/Elixir, Astro, and any
    niche-framework app never see it, even though context7's value
    (live docs vs training-data hallucinations) is universal for any
    project depending on libraries. Two-file fix: add a companion-table
    row in `workflow/skills/recommend-tools/SKILL.md` alongside
    graphify/caveman/llm-wiki, and broaden the JSON `signals` to a
    `package_managers` axis (npm/pnpm/bun/composer/pip/poetry/uv/
    cargo/gem/go.mod) so any dependency-manifest hit scores it.
    Trust model unchanged — preview-then-confirm. Surfaced by
    `/should-i-use context7` 2026-05-23 — verdict on the meta-tool was
    **Ignore** (already wired globally via `~/.claude/rules/context7.md`
    + already in the catalog) but the discoverability gap in
    `recommend-tools` output was the real artifact. Defer-
    rationale: bundle with or after #19's broader signal-table
    restructure to avoid merge conflict.
14. **Re-evaluate book-to-skill as catalog candidate after #22** (#25)
    — `/should-i-use https://github.com/virgiliojr94/book-to-skill`
    2026-05-23 returned **Ignore for now**: a polished MIT Claude
    Code meta-skill that turns one document (PDF/EPUB/DOCX/HTML/RTF/
    MOBI/MD) into a global personal skill at `~/.claude/skills/<slug>/`
    with chapter index, on-demand chapter files, glossary, patterns,
    cheatsheet. Overlaps llm-wiki's slot without a documented category
    boundary (one-shot deep-dive vs continuous wiki maintenance), and
    `#22` (vetting criteria) is the prerequisite before any new
    "personal knowledge / agent memory" catalog category lands. Defer-
    gate: `#22` landed + ≥2 entries in a documented category scored
    against the new criteria + boundary-vs-llm-wiki written down. Then
    re-run `/should-i-use` and promote or close. Cherry-pick noted in
    the issue body (not its own follow-up): book-to-skill's docling
    benchmark (48 tables + 36 code blocks preserved vs pdftotext's 0+0
    on a 103-page technical book) is documented prior art for any
    future llm-wiki PDF-ingest path.
16. **Adopt naschool's DoR/DoD-enforced GH issues + Projects flow** (#27) —
    ai-kit projects have no opinion on issue tracking today. Naschool has
    solved this with a battle-tested GitHub-native stack:
    `.github/ISSUE_TEMPLATE/{feature,spike}.md` embedding Triage (priority /
    epic / area / depends-on / blocks / ready-to-start) + Scope + Acceptance
    + **Definition of Ready** + **Definition of Done** checklists;
    `dor-dod-enforcement.yml` (closes → check DoD, reopens if unchecked;
    `labeled status:in-progress` → check DoR, strips label if unchecked);
    `auto-promote-ready.yml` (Todo → Ready on board #6 when DoR all checked
    AND `P[0-3]-*` + `epic/*` + `area/*` labels set, via ProjectV2 GraphQL).
    Required labels: `P0-critical` / `P1-high` / `P2-medium` / `P3-low`,
    `epic/<name>`, `area/<name>`, `status:in-progress`. **`/should-i-use`
    verdict: adopt-as-pattern.** Delivery: new artifacts under
    `context/templates/github/` (ISSUE_TEMPLATE, workflows, labels.json),
    new skill `setup-gh-workflow` that detects `.github/` + `gh remote` +
    `gh auth`, copies templates idempotently, bulk-creates labels via
    `gh label create --force`, resolves Project IDs via `gh api graphql`
    if board exists (detect-only — never auto-create, that's a silent-
    config anti-pattern). Wired into `/ai:setup` as **Tier-A** —
    always on when a GitHub remote is detected; silent skip on
    non-GH remotes; no opt-in prompt. Also update `to-issues` SKILL
    to use the DoR/DoD structure when project templates present.
    **Decisions baked in:** Tier-A always-on when GitHub-remote
    detected (every ai-kit-on-GitHub repo gets the same bar);
    **Dutch default** with `--lang en` flag for English templates
    (matches naschool source and user's primary language); detect-
    existing-board never auto-create; labels hard-copied from
    naschool (divergence without reason is noise); DoR/DoD parsing
    logic verbatim from naschool (already battle-tested).
15. **Generalise naschool docs-sync into reusable ai-kit primitive** (#26)
    — Tier 1 **landed** 2026-05-23 (commit `3a64907`):
    `bin/hooks/context-drift-check.sh` now fires path-pattern triggers
    in addition to literal-doc-name matches, with per-category reminders
    (model / policy / enum / migration / seeder / route). Built-in
    defaults cover Laravel, Rails, Next/Node, Django. Project override
    via `.ai-kit/drift-triggers.json` replaces built-ins entirely.
    15 new regression tests; 344 total pass.

    **Tier 2 still open**: new `docs-drift` skill wrapping the full
    10-check audit, generalised via `detect-tooling.sh` with project-
    local overrides in `docs/agents/docs-drift.yml`. Wired into
    `/ai:setup` as a Tier-B branch parallel to Branch 11. Sequencing
    risk — skill-vs-companion call (recommend-tools vs core) needed
    first. Migration path: naschool keeps local override until Tier 2
    lands, then re-bootstraps and drops the project-specific bits into
    the YAML config.
17. **Doc-to-skill scaffold (PDF/EPUB/DOCX → `SKILL.md` stub)** (#45) —
    `/should-i-use` of a personal-vault `book-to-skill/extract.py`
    project (2026-05-24) returned **adopt-as-pattern**: the conversion
    mechanics are clean, the PKM-vault assumptions are not. Port
    natively as `bin/doc-to-skill.sh` + `workflow/skills/doc-to-skill/
    SKILL.md` — input a document, output a project-scoped skill stub
    with claims-section + sources list. Different axis from #25
    (catalog-promotion of upstream book-to-skill); can land
    independently once the `/should-i-use` boundary on personal-
    knowledge category (#22-dependent) is settled. Defer-rationale:
    workaround = manual paste; sequence after #25's category-boundary
    decision to avoid duplicate scope.
18. **≥2-source quorum gate for `recommend-*` output** (#46) — `/
    should-i-use` review of a personal-vault session (2026-05-24)
    surfaced an unwritten rule already de-facto applied in
    `recommend-rules` + `recommend-tools`: community items need ≥2
    independent sources before reaching default-on tier. Codify in
    `standards/promotion-quorum.md` and wire user-visible markers
    (`sources: 2/2 verified` vs `single-source — preview only`) into
    both SKILL.md outputs. Different surface from #22 (catalog-entry
    bar) — this is the **recommend-output** bar. Defer-rationale:
    audit shows current output already complies; landing alongside a
    `/ai:retro`-driven hardening pass avoids one-off SKILL.md edits.
19. **Tier-B EOD-email branch in `/ai:setup` for AFK autonomous runs**
    (#47) — `/should-i-use` review of a personal-vault EOD workflow
    (2026-05-24) returned **recommend during setup (optional Tier-B)**:
    `.github/workflows/eod-send.yml` + `eod/trigger.json` + Resend via
    repo secret, push-trigger with `repository_dispatch` fallback,
    proven path. Closes the AFK loop for `/ai:autonomous` runs —
    today the only feedback channel is `progress.txt` + open CC
    session. Defer-rationale: `/ai:autonomous` still in spike status
    (#21 — OpenHands research pending before promotion); wiring an
    async-notification layer against a contract still in motion =
    rework. Sequence after #19's setup-mode opt-in pattern stabilises
    so the question shape can be reused. All three surfaced from one
    `/should-i-use` pass on a vault session (#45/#46/#47 batch).
20. **META: symmetric Tier-B setup branches for all catalog primitives**
    (#48) — **landed** 2026-05-25 (v1.17.0, commit afb698f). DoD met:
    every `standards/external/*.json` has a wiring path; Branch 14
    surfaces all four tool-class catalogs (MCP/hooks/plugins/
    subagents) via `recommend-tools`; `bin/audit-setup-symmetry.sh`
    enforces the lock for future catalogs (test fixture invokes it).
    Re-scope note: pragmatically reused `recommend-tools` as a
    meta-skill covering all tool-class catalogs instead of one skill
    per catalog — avoided ~80% duplicated plumbing while preserving
    the symmetry principle.
21. **`recommend-plugins` skill + setup Tier-B branch** (#49) —
    **closed as already-covered** 2026-05-25. Audit during v1.17.0
    work showed `standards/external/plugins.json` was already wired
    via the `recommend-tools` scorer (`bin/lib/recommend-tools-lib.sh`:
    `emit(plugins_path, 'plugin')`) since v1.12.x. Branch 14
    (#19, v1.16.0) surfaces it through `/ai:recommend-tools --kind
    plugin`. A separate skill would have duplicated ~80% of plumbing
    without adding capability.
22. **`recommend-subagents` skill + `standards/external/subagents.json`
    catalog + setup Tier-B branch** (#50) — **landed** 2026-05-25
    (v1.17.0, commit afb698f). Initial catalog entries:
    `claude-code-guide` (universal docs subagent),
    `caveman:cavecrew-investigator` / `cavecrew-builder` /
    `cavecrew-reviewer`. Scorer extended with fourth `emit()` call;
    `--kind subagent` filter added. Schema mirrors `plugins.json`
    with additional `parent_plugin` (install pointer) + `tools`
    (trust-surface disclosure) fields. Built-in CC subagents and
    ai-kit's own subagents explicitly excluded. Surfaced through
    existing Branch 14 — no separate setup branch needed.

17. **Make plugin self-contained: bundle `bin/` so global clone is
    optional** (#28) — Surfaced 2026-05-23 when naschool's project-
    scope plugin install showed v4.1.0 in `installed_plugins.json` but
    `/ai:status` reported "marker 4.0.0 == VERSION 4.0.0 no drift".
    Root cause: 7 plugin slash-commands call
    `${AI_KIT_ROOT}/bin/*.sh`, which resolves to the global curl-
    install at `~/.local/share/ai-kit` — not the plugin cache. Dual
    install surface, dual update path. Fix: byte-copy `bin/*.sh` into
    `workflow/bin/` via a new `bin/sync-plugin-bin.sh` (mirrors
    existing `sync-plugin-hooks.sh`), repoint commands to
    `${CLAUDE_PLUGIN_ROOT}/bin/`, add drift-detection test.
    Marker-source-of-truth in `/ai:status` should switch to
    `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` in the same
    pass. Optional sidecar: `bin/ai-kit-remove-global.sh` for curl-
    install migrators.

18. **Repo-rename housekeeping: stale path refs in memory-files** (#33)
    — landed 2026-05-25 in v1.19.0. Three primitives shipped together:
    (a) `/ai:rename-housekeeping <old> <new>` skill, backed by
    `bin/rename-housekeeping-core.sh` for the deterministic scan/apply
    engine — snapshots `~/.claude/**` targets to
    `~/.claude/.backups/<ts>/` before write, rewrites via a python utf-8
    helper, updates `known-projects.json`; (b) user-global
    `bin/hooks/rename-detector.sh` SessionStart hook that maintains
    `~/.claude/known-projects.json` (name + path + first_seen +
    last_seen) and emits a one-line nudge only when basename matches a
    known project AND `$PWD` differs from the registered path AND the
    old path is gone on disk — multi-clone case stays silent;
    (c) `bin/install-rename-hook.sh` idempotent installer + Branch 11b
    in `/ai:setup` ("install global rename-detector?"). Pre-write
    validator (option c from the original surfacing) explicitly
    deferred to a follow-up issue — different failure mode (catches
    paths LLM *introduces*, not stale ones already on disk).

19. **Whole-codebase architecture audit skill** (#32) — landed
    2026-05-23 in v1.14.0. New skill `audit-architecture` + canonical
    rule `code-audit.mini.md` (9 dimensions: design patterns, SOLID,
    DRY, YAGNI, naming+comment-drift, coupling, layering, error-
    handling, type-safety). Stack-agnostic; severity-tagged markdown
    report at `docs/reviews/<date>-<scope>-architecture-audit.md`;
    read-only (no code fixes). Issue #32 proposed 8 dimensions —
    review widened to 9 (added error-handling and type-safety; merged
    naming and comment-drift; dropped testability as a cross-cutting
    lens). Two follow-ups filed as fresh issues: #34 (companion
    `audit-fix` skill that consumes the report and runs atomic
    per-finding fixes with user approval) and #35 (per-stack
    tuning extensions `audit-architecture-laravel` / `-react` /
    `-go` etc. that layer stack-specific heuristics on top of the
    stack-agnostic core).

20. **triage↔autonomous Agent Brief contract** (#36) — landed
    2026-05-23 in v1.14.1 (PR #37). Surfaced on a live naschool run
    (#42/#43/#44, EPIC #41 backend refactor): `/ai:triage` produced
    `## Triage outcome` comments referencing an external plan-doc,
    while `/ai:autonomous` searches for `## Agent Brief` literally and
    does not follow links. Three issues labeled `ready-for-agent` were
    invisible to the drainer despite triage formally succeeding.
    `triage/SKILL.md` now requires the brief comment atomically with
    the label (no label-only state), the literal `## Agent Brief`
    header (not `## Triage outcome`, which is reserved for
    `needs-info`), and inline acceptance criteria (plan-doc references
    rejected — cold-start contract). Quick-state override no longer
    makes the brief optional. `autonomous/SKILL.md` `exit-gate
    brief-thin` now carries a diagnostic detail string —
    `header-mismatch` / `body-not-promoted` / `no-brief` — each
    recommending `/ai:triage <n>` to re-emit. Body-fallback in
    autonomous was considered and rejected: it would have broken the
    "brief = contract" durability principle in `AGENT-BRIEF.md`.

21. **autonomous hardening: cwd-guard + telemetry + exit-handoff**
    (#38, #39, #40) — landed 2026-05-23 in v1.14.2. First real-queue
    drain on naschool #42 (EPIC #41 Chunk A: 18 dir deletes, 24
    call-site rewrites, 4 moves, vocab doc, CLAUDE.md rewrite)
    surfaced three orthogonal gaps. **Safety (#39):** CC harness
    resets cwd to session-primary working dir after every Bash, so
    when the user starts CC from the master worktree but the brief
    targets a sibling worktree, every `cd X && cmd` ends with cwd
    back on master. Skill discipline was the only guard. v1.14.2
    adds a hard precondition step 0 — parse `target_worktree` +
    `target_branch` from the brief, compare against `$(pwd)` and
    `git rev-parse --abbrev-ref HEAD`, exit-gate `cwd-mismatch` /
    `branch-mismatch` before pick; trust-model gains a "never
    operate outside the brief's declared worktree" bullet.
    Recommended worktree layout codified: `<repo-root>/.agents/
    worktrees/<branch-slug>` — inside-project, makes cwd-confusion
    impossible when CC starts from repo root. **Observability (#38):**
    `progress.txt` had a 20-minute silent gap between `brief-ok` and
    next event, making "LLM thinking" indistinguishable from
    "process dead". New `bin/autonomous-heartbeat.sh` writes a
    `heartbeat` line per 60s wall-clock while the skill is alive,
    killed via trap on EXIT; per-attempt `cycle-attempt C-id
    attempt=N result=pass|fail` events plus per-cycle `cycle-done
    C-id result=...` events add real-time progress. SKILL.md adds a
    "Real-time view" subsection pointing at the CC session
    transcript (`~/.claude/projects/<slug>/sessions/*.jsonl`) as
    the authoritative live-view. **Handoff (#40):** the live drain
    aborted mid-verification due to harness instability; skill
    invented `exit-handoff` to gracefully hand state back to the
    user (worktree changes preserved uncommitted, chat-output
    recipe for manual cycle-split + gate-running). v1.14.2
    formalises `exit-handoff` as a first-class non-error
    termination with its own stop-conditions row and a Handoff
    protocol section. Trust-model addition: never escalate
    `exit-handoff` to `exit-error`. Together these unblock
    tomorrow's #42 re-drain attempt with mechanical safety,
    diagnosable progress, and a clean abort path.

22. **broader CC-primitive ecosystem audit + convergence** (#41) —
    landed 2026-05-24 in v1.15.0. `/ai:dedupe` and `/ai:setup` were
    blind to host-side Claude Code state beyond their four narrow
    surfaces; on naschool the rename `school-activities-hub` →
    `naschool` left stale `projectPath` refs in
    `~/.claude/plugins/installed_plugins.json` and `/ai:dedupe`
    still reported `clean — no duplicates or orphans found`. User
    reframe (2026-05-24): ai-kit should *replace* the scattered
    status-quo, not just report on it — every host primitive needs a
    convergence verdict (add/move/update/delete) against ai-kit's
    single source of truth. New `bin/ai-kit-audit-ecosystem.sh` is a
    read-only auditor that walks installed plugins, known
    marketplaces, user-scope skills/agents/rules, and user-settings
    MCP servers, cross-checking each against
    `standards/external/{plugins,mcp-servers}.json` +
    `workflow/{skills,agents}/` + `standards/rules/`. Per-item
    verdict: `OWNED` (catalog match), `ADOPT` (promotion
    candidate), `REBIND` (scope mismatch — project-scoped where
    user-scope makes sense, or duplicate marketplace install),
    `REPLACE` (ai-kit ships equivalent), `DROP-STALE`
    (`projectPath` missing on disk), `KEEP-EXTERNAL` (valid
    out-of-scope). Flags: `--json`, `--scope`, `--converge`
    (prints migration recipe — `/plugin uninstall`,
    `/plugin install --scope user`, `rm`, `/plugin marketplace
    remove` — but does NOT execute), `--home` and
    `--catalog-root` for test-fixture injection. `bin/ai-kit-dedupe.sh`
    gained Surface 5 wired through `--no-ecosystem` opt-out; JSON
    output embeds the `ecosystem` block verbatim alongside
    `dup_skills` etc. `workflow/commands/dedupe.md` documents the
    verdict tokens. `workflow/skills/recommend-tools/SKILL.md`
    gained Phase 0 Inventory that runs the auditor before
    recommending, so already-wired tools are noted as such (no
    double-recommend) and `ADOPT`/`REBIND`/`REPLACE` findings
    surface for user action *before* Phase 3 wiring. Tests:
    fixture tree under `tests/bin/fixtures/audit-ecosystem/` with
    synthetic `installed_plugins.json` covering every verdict
    class; `tests/bin/cases/audit-ecosystem.sh` (30 assertions);
    `tests/bin/cases/dedupe.sh` extended to assert Surface 5
    presence (5 extra assertions). 449 tests pass total. Real-
    machine smoke on the dev host: 66 items inspected, 9
    divergent — confirmed `ai@yusufkaracaburun` project-scoped to
    naschool only (should be user), `superpowers` installed from
    two different marketplaces, 4 plugin promotion candidates
    (`context7`, `claude-code-setup`, `csharp-lsp`, `caveman`).
    Non-goals deferred to follow-ups: auto-promote of `ADOPT`
    candidates (gated by VETTING.md / `/should-i-use`), auto-
    uninstall of `DROP` entries (recipe-only, user runs it),
    standalone `/ai:converge` slash command (promote later if
    `--converge` usage shows it's worth the surface).

23. **ecosystem-audit polish: report-only, self-ref, deliberately-
    excluded** (v1.15.2) — landed 2026-05-24. First real-world use
    on naschool surfaced four shortcomings of v1.15.0/v1.15.1.
    **Exit-code UX:** Claude Code's slash-command runner treats any
    non-zero exit as red `Error:` — users mistook divergent findings
    for script failure. Both `bin/ai-kit-dedupe.sh` and
    `bin/ai-kit-audit-ecosystem.sh` now default to exit 0 (report-
    only contract) and accept `--strict` to opt in to exit 1 when
    findings present (intended for CI). **Self-reference:** v1.15.0
    hardcoded the `ai@yusufkaracaburun` exclusion which (a) broke
    when ai-kit's own catalog detection logic considered it
    uncatalogued, mislabeling it `ADOPT`, and (b) didn't generalise.
    Replaced with manifest-driven self-detection — the script reads
    its own `workflow/.claude-plugin/plugin.json` `name` field and
    skips that name from ADOPT classification (project-scoped
    self-ref still flags `REBIND`). **Deliberately-excluded
    plugins:** new `standards/external/plugins-excluded.json`
    enumerates plugins ai-kit consciously did NOT add to its
    catalog — typically meta-skill bundles (superpowers, gsd,
    mattpocock-skills) whose best ideas were already distilled
    into ai-kit's own lifecycle during initial design. Auditing
    these as `ADOPT` (promotion candidate) was wrong — they're
    `REPLACE` (ai-kit has equivalent, recommend uninstall) with the
    `alternative` field surfaced inline in the verdict reason and
    the convergence recipe (`/plugin uninstall <name>   # ai-kit
    equivalent: <alternative>`). First entry: superpowers, with
    `Use ai-kit's own lifecycle skills` as the alternative.
    **Plugin standards bundling:** v1.15.1 hotfix (`bin/sync-
    plugin-standards.sh`) confirmed in production — plugin install
    on naschool went from 21 false-divergent (catalog missing) to 9
    real divergent. Tests: 455 pass (+6 since v1.15.0). Follow-ups
    parked as ai-kit#42/#43/#44 (catalog-candidates for context7 /
    claude-code-setup / caveman, filed via `/ai:to-prd defer` from
    naschool — labeled `enhancement` fallback because `catalog-
    candidate` label did not yet exist on this repo; v1.15.2 adds
    the label + relabels the three issues).
