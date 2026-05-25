# Changelog

## 1.16.0 — 2026-05-25

Closes #19: `/ai:setup` now wires `/ai:recommend-tools` as a first-class
Tier-B branch (Branch 14), parallel to Branch 12 (rule recommendation).
Before: setup only mentioned `recommend-tools` as a one-liner at the
end — users had to know to re-invoke it. After: setup actively offers
to refine the companion-tool / MCP-server / Claude-Code-hook catalogs
against the detected stack.

Trust model unchanged — preview-then-confirm inside `recommend-tools`,
never auto-install. Brownfield with a detected framework defaults to
offering the branch; greenfield or stack-less projects default to
`skipped`.

Sets the pattern for #48 (setup-symmetry meta) — every
`standards/external/<category>.json` will eventually have a matching
Tier-B branch. #49 (recommend-plugins) and #50 (recommend-subagents)
follow this template once their catalog prerequisites land.

- **New** Branch 14 in `workflow/skills/setup/SKILL.md` — `[1] Refine now /
  [2] Later / [3] Keep default` prompt; defaults documented; marker
  key documented.
- **Updated** `bin/write-setup-marker.sh` — accepts
  `--tool-recommendation=completed|deferred|skipped`, writes
  `branches.tool_recommendation` in `.ai-kit-setup`.
- **Updated** `tests/bin/cases/apply-marker.sh` — 4 new assertions
  covering tool-recommendation absent-without-flag, round-trip, and
  preservation of sibling keys across re-writes. 39 total pass.
- **Removed** the orphan one-liner at the end of `setup/SKILL.md`
  that previously surfaced `recommend-tools` as a follow-up —
  superseded by Branch 14.

## 1.14.0 — 2026-05-23

Closes #32: new skill `audit-architecture` + canonical rule
`code-audit.mini.md`. Whole-codebase architecture-quality audit
against 9 dimensions, stack-agnostic, read-only, writes a severity-
tagged markdown report — fixing is a separate step.

Issue #32 proposed 8 dimensions. Reviewed the catalogue before
shipping:

- Folded "Comments/docs drift" into "Naming" (same intent-vs-text
  theme; standalone bucket was thin).
- Added "Error handling / failure modes" (swallowed exceptions,
  silent fallbacks, retry-without-backoff, race smells).
- Added "Type safety / contract clarity" (escape-hatch types,
  stringly-typed APIs, missing nullability, boolean-flag args).
- Sharpened the coupling-vs-layering separation: coupling is
  local/structural, layering is global/architectural.
- Rejected a "Testability" bucket — manifests as SOLID-DIP or
  coupling findings and would double-count.
- Explicitly out-of-scope: security (use `/ai:review` deep pass),
  performance, runtime profiling, pre-merge diff review.

Issue #32 options B (companion `audit-fix` skill) and C (per-stack
tuning extensions like `audit-architecture-laravel`) are deferred
to fresh follow-up issues — they need their own design and
shouldn't bloat v1.14.0.

- **New** `standards/rules/code-audit.mini.md` — frontmatter
  `universal: true`, `weight: medium`, `default_mode: on-demand`.
  Body covers the 9 dimensions, severity tagging (🔴/🟠/🟡/🟢),
  output contract (`docs/reviews/<date>-<scope>-architecture-audit.md`),
  and anti-patterns.
- **New** `workflow/skills/audit-architecture/SKILL.md` — invocable
  workflow. References the rule as the canonical catalogue. Delegates
  the codebase walk to the `explore` subagent on Claude Code; falls
  back to inline walk on hosts without subagents. Always read-only.
- **Updated** `tests/bin/cases/bootstrap-emit.sh` — `--list` count
  24 → 25, adds `code-audit listed` + source-file + `universal: true`
  assertions.
- **Updated** plugin manifest + README from 27 skills → 28 and
  24 rules → 25. README skill table gets a new `audit-architecture`
  entry under Cross-cutting.

## 1.13.0 — 2026-05-23

Closes #29: new canonical rule `domain-model-first`. Captures the
naschool 2026-05-23 "domain-model blindness" lesson from
`~/.claude/ai-kit-lessons.md` as a reusable, stack-agnostic primitive.
Ships universal so every `/ai:setup` run pulls it in.

The rule absorbs option C from the issue (verify-state generalisation)
as a sub-clause and skips option B (plan-mode gate) — that requires
harness changes ai-kit doesn't control.

- **New** `standards/rules/domain-model-first.mini.md` — frontmatter
  `universal: true`, `weight: high`, `default_mode: always-on`. Body
  covers when-the-gate-fires (architecture/schema verbs near domain
  nouns; entity names from CONTEXT.md; new-migration proposals),
  how-to-apply (locate canonical layer per-stack, read entity +
  related entities, verify don't assume, prefix proposal with
  evidence, prefer extending), when-to-skip (cosmetic / explicit
  user override / no-domain-layer), and a concrete anti-pattern
  using the naschool subsidy example.
- **Updated** `tests/bin/cases/bootstrap-emit.sh` — `--list` count
  23 → 24, adds `domain-model-first listed` assertion.
- **Updated** plugin manifest + README from 23 → 24 canonical rules.

Tests: 410 passed, 0 failed.

## 1.12.1 — 2026-05-23

Closes #24: surface `context7` more prominently in `/ai:recommend-tools`.
The pain was a closed framework signal-list — Phoenix repos, Go services,
Rust CLIs, niche stacks never saw the recommendation even though
context7's value (live docs vs. training-data hallucinations) is universal
for any project depending on third-party libraries.

- **Updated** `standards/external/mcp-servers.json` — context7 entry now
  carries `"universal": true`. The deterministic recommender's `universal`
  axis (already wired for hooks + plugins) now applies to MCP too, so
  context7 surfaces on every stack while keeping its framework/dependency
  boosts for ranking.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — companion
  table grows from three rows to four (graphify / caveman / llm-wiki /
  context7). Note clarifies context7 is the one universal companion.
- **Updated** `tests/bin/cases/recommend.sh` — empty-stack assertion
  inverted: was "no MCP recs", now "only context7 surfaces (universal),
  no stack-specific MCPs". Adds direct `name == "context7"` assertion.

No new primitives. Trust model unchanged (preview-then-confirm). Lands
ahead of #19's wider signal-table restructure; the additive
universal-flag pattern survives a future scorer refactor cleanly.

## 1.12.0 — 2026-05-23

New `/ai:onboard` skill wraps the harness `ShareOnboardingGuide` tool — drafts
a project-scoped `ONBOARDING.md` from existing artifacts (README, CONTEXT.md,
`.ai-kit-setup`, ADRs), confirms with the user, then publishes a short-link.
Composes with `/ai:handoff`: handoff = leaves a machine, onboard = arrives
at a project.

- **New** `workflow/skills/onboard/SKILL.md` — full template + audience
  scoping + idempotent re-run contract (refreshes the existing guide; same
  short-link keeps working).
- **New** `tests/eval/prompts/onboard/new-contractor-arriving.md` —
  eval-structure requires ≥1 fixture per skill.
- **Updated** count assertions: `structure.sh` (26→27 skills, adds onboard
  existence assertion), `release-install.sh` (`which --list`: 26→27).
- **Updated** plugin manifest + README + architecture/install/mental-model
  docs from 26 → 27 skills.

## 1.11.0 — 2026-05-23

`/ai:setup` now offers the v1.9.0 repo template pack as an optional Tier B
branch — per-file consent, default skip when a file already exists, no new
bin script (skill prompt drives a plain `cp`).

- **Updated** `workflow/skills/setup/SKILL.md` — adds Branch 13 "Repo
  templates" to the Tier B table, a full section with source/destination
  table + per-file copy contract, marker shape extension
  (`repo_templates: skipped|all|picked`), and the Done-step marker
  invocation now passes `--repo-templates=...`.
- **Updated** `bin/write-setup-marker.sh` — accepts
  `--repo-templates=all|picked|skipped` and persists it under
  `branches.repo_templates`. Backward-compatible: the flag is optional,
  marker JSON omits the field when not passed.

No new skills/commands/rules. Test count stays at 407.

## 1.10.2 — 2026-05-23

Regression-lock for v1.3.0–v1.10.0 surface changes. All tests green
(407 passed, 0 failed) on a fresh `tests/bin/run-all.sh`.

- **New test case** `tests/bin/cases/dedupe.sh` — 13 assertions covering
  `ai-kit-dedupe.sh` help / JSON shape / orphan rule detection /
  --fix-prints-but-doesn't-execute / unknown-flag rejection.
- **Updated** `tests/bin/cases/recommend.sh` — adds `--kind plugin`
  filter test, `laravel-boost` + `claude-mem` surface assertions,
  universal-plugin-on-empty-stack assertion. Adjusts the
  "kind in {mcp,hook}" assertion to include `plugin` (v1.8.0 surface
  change).
- **Updated** count assertions: `structure.sh` (23→26 skills, 7→8
  commands incl. new `dedupe` command), `release-install.sh`
  (`which --list`: 23→26), `bootstrap-emit.sh` (`emit-rules --list`:
  8→23).
- **New eval fixtures** for the three new skills:
  `tests/eval/prompts/{should-i-use,feedback,contribute-eval}/*.md`.
  Each fixture has frontmatter `expects[]` listing the testable
  behaviours, which the eval-structure check requires.
- **Plugin manifest** `workflow/.claude-plugin/plugin.json` description
  bumped to mention 26 skills / 8 commands / 23 rules / feedback loop
  + curated MCP/hook/plugin recommendations.

No surface or behaviour change in the skills/rules themselves.

## 1.10.1 — 2026-05-23

Docs sync — README + architecture + install-plugin + mental-model
all referenced stale counts from the v1.0 release (23 skills, 7
commands, 7 rule books). No surface or behaviour change.

Updated counts in README to current totals: 26 skills, 8 slash
commands, 23 canonical mini-rules, 21 MCP + 25 hooks + 12 plugins
curated, 5 repo templates. Added Feedback Loop section (`/ai:feedback`
+ `/ai:contribute-eval`). Pin-release example bumped to v1.10.0.

## 1.10.0 — 2026-05-23

Stack-specific micro-rules pack — 5 new rules gated on detected stack.

- `laravel-conventions.mini.md` — Eloquent, Form Requests, queues
  (idempotent + `WithoutOverlapping`), Artisan, multi-tenancy via Global
  Scope. Fires on `laravel` framework.
- `tailwind.mini.md` — utility-first discipline, tokens in `tailwind.config`
  not literals, `cn()`+`cva` patterns, mobile-first responsive order,
  `focus-visible:` over `focus:`. Fires on `tailwindcss`.
- `prisma.mini.md` — schema-first, narrow `include`/`select`, cursor
  pagination, explicit transactions, N+1 detection, no
  `$queryRawUnsafe`. Backend architecture.
- `react-rsc.mini.md` — Server Components by default, push `"use client"`
  down the tree, async data fetch in RSC, Server Actions for mutations,
  Suspense per independent slow region. Fires on `nextjs`/`remix`.
- `sql-style.mini.md` — UPPERCASE keywords, no `SELECT *`, explicit
  `INNER JOIN`, half-open date ranges, parameterised queries always,
  `RETURNING` for one-roundtrip writes.

All 5 use `universal: false` + framework/architecture signals so they
only score when the relevant stack is detected — keeps the universal
rule set lean for stack-agnostic repos.

Shipping surface at v1.10.0:

- 26 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- **23 canonical rules** (was 18) under `standards/rules/`
- 21 curated MCP servers + 25 curated hook recipes + 12 curated plugins
- 5 repo templates under `context/templates/repo/`

## 1.9.0 — 2026-05-23

Repo template pack — drop-in baseline files under
`context/templates/repo/`. Quick win, real toil saved per new repo.

Added templates:

- `.editorconfig` — charset, line endings, per-language indent overrides
  (Python 4, Go tabs, Markdown preserves trailing whitespace).
- `.gitattributes` — LF normalisation, binary markers, `-diff` on
  lockfiles.
- `CODEOWNERS` — empty template with examples for default, backend,
  frontend, infra, docs, and security-critical paths.
- `renovate.json` — Renovate Bot defaults: weekly cadence, dependency
  dashboard, semantic commits, auto-merge for non-major dev-deps,
  major bumps human-gated, GH Actions pinned to SHA.
- `.envrc` — direnv stub with commented hooks for Node/Python/PHP
  version pinning.
- `README.md` — what each file does and when to use it.

Templates are available now via `$AI_KIT_ROOT/context/templates/repo/`;
`/ai:setup` integration as an optional offer-step is queued for a
future minor (no skill change in this release).

Shipping surface at v1.9.0:

- 26 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes + 12 curated plugins
- **5 repo templates** under `context/templates/repo/`

## 1.8.0 — 2026-05-23

Complete the `recommend-tools` curation triad (MCP / hook / **plugin**).

- **New curation file** `standards/external/plugins.json` — 12 curated
  third-party Claude Code plugins with stack signals and one-line install
  commands:
  - `claude-mem`, `tdd-guard`, `ask-questions-if-underspecified`,
    `claude-md-management`, `skill-creator` — universal
  - `github`, `laravel-boost`, `frontend-design`, `lazyweb`,
    `chrome-devtools-mcp`, `typescript-lsp`, `php-lsp` — stack-gated
  Each entry includes `marketplace` and `install` fields so the skill
  can surface the exact `/plugin install <name>@<marketplace>` command
  without guessing.
- **Scorer extended** (`bin/lib/recommend-tools-lib.sh`,
  `bin/recommend-tools.sh`) — loads `plugins.json` (optional; older
  clones without the file skip silently), emits rows with
  `kind="plugin"`, accepts `--kind plugin` filter alongside existing
  `mcp` / `hook` / `all`.
- **Skill update** `recommend-tools` — documents the third surface,
  trust posture for plugin install ("never auto-install — show the
  `/plugin install` command, user pastes"), marketplace-registration
  caveat.

Smoke-tested against the ai-kit repo: scorer surfaces 5 plugins,
2 MCP servers, 7 hooks. `--kind plugin` filter works.

Shipping surface at v1.8.0:

- 26 skills (unchanged; 1 edited — recommend-tools)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes + **12 curated
  Claude Code plugins**

## 1.7.0 — 2026-05-23

Close the user feedback loop (Phase 2 of < 50-user feedback design).

- **New skill** `contribute-eval` (`workflow/skills/contribute-eval/`) —
  turns a skill failure into a regression test by composing a prompt
  fixture (`tests/eval/prompts/<skill>/<scenario>.md`) plus a golden
  rubric (`tests/eval/goldens/<skill>/<scenario>.md`) and opening a PR
  against `yusufkaracaburun/ai-kit`. Captures the verbatim prompt, the
  actual output, and the user's expected-behaviour bullets; derives
  rubric fields conservatively from those bullets (no invented
  `required_keywords`). Reuses the same redaction rules as
  `/ai:feedback` (paths, secrets, tenant names, emails). One case per
  PR; previews both files + full PR body before any write.

Motivation: `/ai:feedback` captures *that* something is wrong;
`/ai:contribute-eval` captures *what* would have been right and locks
it into CI. The two skills are a pair — feedback ⇒ triage ⇒
contribute-eval ⇒ PR ⇒ CI gate. Every contributed case becomes a
regression test the next release must pass.

Shipping surface at v1.7.0:

- 26 skills (was 25) — adds `contribute-eval`
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.6.0 — 2026-05-23

Open the user feedback loop (Phase 1 of < 50-user feedback design).

- **New skill** `feedback` (`workflow/skills/feedback/`) — walks the user
  through one structured piece of feedback (friction/surprise/clarity/
  gap/win), redacts absolute paths and secret-shaped strings from any
  context block, and opens a GitHub issue against `yusufkaracaburun/ai-kit`
  using the new `feedback.yml` template. Never publishes without showing
  the final body first.
- **New issue template** `.github/ISSUE_TEMPLATE/feedback.yml` — structured
  feedback form with kind dropdown, area multi-select, situation /
  friction / better fields, optional redacted-context block, redaction
  checkbox gates.
- **New issue config** `.github/ISSUE_TEMPLATE/config.yml` — disables
  blank issues, points open-ended chat to Discussions, keeps the issue
  tracker reserved for trackable work.

Motivation: at < 50 users, telemetry pipelines are premature; GitHub +
a guided capture skill is enough to compound user feedback into PRDs
via the existing `/ai:triage` → `/ai:to-prd` flow. Phase 2 (eval-loop
contributions) and Phase 3 (recommendation engine) deferred until
inflow justifies them.

Shipping surface at v1.6.0:

- 25 skills (was 24) — adds `feedback`
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.5.0 — 2026-05-23

Mini-rules pack — 8 new canonical rules under `standards/rules/`.

Universal (always-on, weight high/medium/low):

- `testing-pyramid.mini.md` — 70/25/5 unit/integration/E2E discipline,
  no flaky-retry-in-CI, bug fixes ship with regression tests.
- `error-handling.mini.md` — validate at boundaries, trust internal code,
  never swallow errors, throw vs return guidance.
- `observability.mini.md` — structured logs, RED/USE metrics, OpenTelemetry
  traces, cardinality discipline.
- `secrets-hygiene.mini.md` — never commit/log secrets, single secret store
  per env, rotation playbook, gitleaks in pre-commit + CI.
- `semver.mini.md` — MAJOR/MINOR/PATCH bump rules, deprecate-before-remove,
  CHANGELOG-in-same-commit discipline.

Stack-specific (fire on matching architecture):

- `a11y.mini.md` — WCAG 2.2 AA baseline for frontend stacks (react, vue,
  angular, nextjs, nuxt, svelte, remix, astro).
- `api-design.mini.md` — REST conventions, status codes, OpenAPI as source of
  truth for backend frameworks (express, fastify, nestjs, fastapi, django,
  rails, laravel, spring).
- `twelve-factor.mini.md` — 12factor.net discipline for backend services.

Smoke-tested against the ai-kit repo: 6/8 new rules score in
`recommend-rules.sh --json` (universal ones); stack-specific 3 require
frontend/backend detection to score, working as designed.

Shipping surface at v1.5.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (was 10) under `standards/rules/`
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.4.1 — 2026-05-23

Drop `notion`, `figma`, `mongodb` from MCP curation per maintainer
decision — narrowing recommend-tools surface to servers we actively use
or actively recommend. MCP count: 24 → 21.

## 1.4.0 — 2026-05-23

Expand `recommend-tools` curation with 9 MCP servers and 9 hook recipes.
Pure data — no scorer or skill changes.

**MCP additions (`standards/external/mcp-servers.json` 15 → 24):**

- `obsidian` — Obsidian vaults (`.obsidian/`)
- `notion` — Notion docs/PRDs/roadmap (`@notionhq/client`, `notion-sdk-py`)
- `figma` — Frontend with Figma design files (`figma-api`, `figma-export`)
- `stripe` — Payments/subscriptions (`stripe`, `stripe/stripe-php`)
- `mongodb` — Direct MongoDB access (`mongoose`, `pymongo`)
- `redis` — Cache/queue/pubsub (`redis`, `ioredis`, `predis/predis`)
- `mysql` — Direct MySQL/MariaDB access (`mysql2`, `pymysql`)
- `firecrawl` — Web scraping / doc ingestion (`firecrawl-py`)
- `exa` — Semantic web search (`exa-py`, `exa-js`)

**Hook additions (`standards/external/hooks-patterns.json` 16 → 25):**

- `phpstan` (PHP static analysis) — `phpstan.neon`
- `cargo-clippy` (Rust lint) — `Cargo.toml`
- `swift-format` (Apple swift-format) — `Package.swift`
- `dart-format` (Dart/Flutter) — `pubspec.yaml`
- `commitlint` (Conventional Commits enforcement) — `commitlint.config.*`
- `gitleaks-scan` (block secrets on write) — universal
- `branch-guard` (warn/block edits on protected branch) — universal
- `large-diff-warn` (surface big single-edit warnings) — universal
- `pre-commit-run` (reuse project's pre-commit framework) — `.pre-commit-config.yaml`

Motivation: `recommend-tools` scorer already consumes both JSON files; adding
entries instantly widens stack coverage without touching any code path.

Shipping surface at v1.4.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 10 canonical rules (unchanged)
- 24 curated MCP servers + 25 curated hook recipes

## 1.3.0 — 2026-05-23

Add duplication detection for safer plugin updates.

- **New slash command** `/ai:dedupe` — scans four surfaces and reports
  duplicates/orphans without ever deleting:
  1. Personal skills (`~/.claude/skills/`) shadowing plugin skills.
  2. Personal agents (`~/.claude/agents/`) shadowing plugin agents.
  3. Orphan emitted rules (`.cursor/rules/ai-kit-*.mdc`) whose canonical
     source no longer exists in the plugin (stale after rule rename/removal).
  4. Hook overlap in project `.claude/settings.json`.
- **New bin script** `bin/ai-kit-dedupe.sh` — supports `--json` and `--fix`
  (prints suggested `rm` commands, never executes). Exit 0 = clean, 1 = dups.
  Mirrored to `workflow/bin/` so it ships in the plugin.

Motivation: every `/plugin update` risks personal-skill shadowing and orphan
emitted rules accumulating silently. `/ai:dedupe` surfaces them on demand
without auto-deleting anything — user always reviews the cleanup commands
before running them.

Shipping surface at v1.3.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (was 7) — adds `/ai:dedupe`
- 10 canonical rules (unchanged)

## 1.2.0 — 2026-05-23

Codify "grill before plan" — prevent agents from jumping straight to plan
or implementation when handed an issue/PRD/spec that *looks* complete.

- **New rule** `grill-first.mini.md` (`standards/rules/`) — universal, high
  weight. Specifies when the grill gate fires, the minimum question set
  (scope split, detection logic, override pattern, bundle-vs-defer, data
  contract), routing to `grill-with-docs` vs `grill-me`, and when to skip.
- **Skill update** `to-issues` — inserts a 1.5 Grill-first gate between
  "Gather context" and "Explore the codebase", with explicit reference to
  the new rule.
- **Skill update** `tdd` — adds grill-first as a precondition before the
  first failing test, alongside the existing `context-discipline` link.

Motivation: Issue bodies, PRDs, and memory anchors look deterministic but
are almost always under-specified. Discovering that mid-plan = wasted
context. Discovering it pre-plan = cheap. Prevention beats cure.

Shipping surface at v1.2.0:

- 24 skills (unchanged; 2 edited)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 10 canonical rules (was 9) under `standards/rules/`

## 1.1.0 — 2026-05-23

Surface expansion from personal `~/.claude/` companions.

- **New skill** `should-i-use` (`workflow/skills/should-i-use/`) — structured
  vendor / wire / adopt / ignore verdict for any candidate tool, repo, URL, or
  pasted artifact. Critical-advisor variant of `/ai:triage` for inbound tooling.
- **New rule** `context7.mini.md` (`standards/rules/`) — canonical
  ctx7 CLI usage guidance. Pairs with the existing `context7` MCP entry in
  `standards/external/mcp-servers.json` to close the docs-lookup loop.

Shipping surface at v1.1.0:

- 24 skills (was 23)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 9 canonical rules (was 8) under `standards/rules/`

## 1.0.0 — 2026-05-23

Initial release after version-history reset. Prior tags (v1.0.0–v5.0.2)
were deleted from origin on 2026-05-23 to consolidate the rapid pre-1.0
churn that accumulated during the May 2026 primitive-expansion + plugin
distribution work. Git history of `master` is preserved — only version
tags + this CHANGELOG were reset.

Current shipping surface at v1.0.0:

- 23 skills (workflow/skills/)
- 3 subagents (workflow/agents/)
- 7 slash commands (workflow/commands/)
- Self-contained Claude Code plugin distribution (workflow/bin/, workflow/hooks/)
- Cursor + Claude Code rule emitters (bin/lib/emitters/{cursor,claude-code,generic}.sh)
- 387-test regression suite
