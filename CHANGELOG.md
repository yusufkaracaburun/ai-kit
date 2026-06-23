# Changelog

## 1.43.1 — 2026-06-23

### Changed

- **`plugins-excluded.json` +1: `codebase-memory-mcp`** (DeusData/codebase-memory-mcp, MIT). should-i-use verdict **Ignore**: a tree-sitter + Hybrid-LSP code-intelligence MCP that is an *alternative* to graphify (ai-kit's knowledge-graph/input companion), not complementary — its own README calls itself "similar in spirit to graphify's graphify-out/". Two knowledge-graph tools = double-bundle noise; also runs against ADR-0006 (ai-kit deliberately dropped MCP, stays pure Bash+Markdown). Whether it should *replace* graphify is a deliberate spike, not a catalog add — tracked in #109.

### Notes

Patch release: marketplace was stranded at v1.40.0 (3 releases behind); this cut captures the untagged `codebase-memory-mcp` ledger commit so the marketplace can advance to a tag that includes all of master. Data-only (catalog ledger); no scorer/skill/schema change.

## 1.43.0 — 2026-06-22

### Added

- **`recommend-tools` surfaces deliberate exclusions** — new Phase 2b reads `standards/external/plugins-excluded.json` and lists every excluded tool (name + one-line reason) as a "considered, not adopted" curation boundary. Closes the gap where the ecosystem audit's `KEEP-EXTERNAL` path only fired for *already-installed* tools, so a fresh project never learned what ai-kit deliberately rejected. `/ai:setup` Branch 14 points at the behavior; surfaced in the recommend-tools output contract.

### Changed

- **`plugins-excluded.json` +1: `designlang`** (Manavarya09/design-extract). should-i-use verdict **Ignore**: a live-DOM design-system *extraction* tool that ships an MCP server (structurally mcp-bucket-eligible) but optimizes none of the companion catalog's AI-loop dimensions, fails the promotion-quorum bar (single-maintainer, v12.x high-churn, sponsor-affiliate README → preview-only), and is one-shot task tooling, not durable per-project infra. Same out-of-scope bucket as `taste-skill`. Direct-install pointer kept in the entry's `alternative`.

### Notes

LEAN: catalog data + SKILL.md prose only; no scorer/script/schema change. `audit-setup-symmetry` green; standards mirror identical.

## 1.42.0 — 2026-06-14

### Added

- **shadcn MCP recommendation** (closes #102) — `standards/external/mcp-servers.json` gains a `shadcn` entry keyed on the existing `shadcn` framework signal (a `components.json` with the shadcn schema). `/ai:recommend-tools` now surfaces it for any shadcn project with install paths (`npx shadcn@latest mcp init --client claude` for project scope; `claude mcp add --scope user shadcn -- npx shadcn@latest mcp` for monorepos) + scope guidance (one components.json → project, several → user). Commands verified against shadcn docs.
- **`pre-write-gate` hook recipe** (closes #101) — `standards/external/hooks-patterns.json` gains a universal `PreToolUse` (Edit|Write|MultiEdit) hook recommendation that surfaces the 4-principle pre-write checklist (assumptions · minimum · surgical · verifiable) as non-blocking context before edits. Closes the gap where auto-loaded CLAUDE.md rules are present but never gated at edit time — an enforcement layer that holds regardless of which skill is active. Opt-in via `/ai:recommend-tools` (ai-kit recommends, never auto-wires).

### Changed

- **`/ai:checkpoint` housekeeping** (closes #103) — the end-of-checkpoint hygiene/docs-sync nudge becomes an inline run. Default is **report-only**: it runs `/ai:hygiene` + `/ai:docs-sync` (same applicability gates), embeds a `## Housekeeping` section (score + per-check summary + Applied/Needs-approval split) in the memo, and mutates nothing. `--also-housekeeping` additionally auto-applies the safe idempotent fixes (MEMORY.md dead-links, empty-dir rmdir, finished-work branch cleanup); risky items are never auto-applied. `--skip-housekeeping` falls back to the old cheap nudge. (Default kept non-mutating by design — a memo command should not change branches/files unprompted.)

### Docs

- Cite Addy Osmani's *Loop Engineering* as external validation in `docs/spikes/aikit-autonomous-ralph.md` (closes #107) — new `## External validation` section maps the essay's six primitives 1:1 onto ai-kit/CC-harness surfaces and ties its "comprehension debt / cognitive surrender" framing to the spike's trust model.

### Notes

LEAN: #101/#102 are catalog data only (no scorer code); #103/#107 are SKILL.md / doc prose. Regression asserts added for shadcn (#102) and pre-write-gate (#101). Full suite 912 passed / 0 failed.

## 1.41.2 — 2026-06-14

### Fixed

- ai-kit's own `/ai:docs-sync` now reports **0 dead links** on the repo (was 28). Root causes, all fixed:
  - **5 real cross-reference bugs** in canonical skills — `grill-me`, `improve-codebase-architecture`, `setup` linked siblings as `../ai:<skill>/SKILL.md`, but the directories are `<skill>` (no `ai:` prefix). Stripped the prefix; all targets resolve.
  - **Dead-link checker matched links inside inline code spans** — link-syntax examples written as inline code (in CHANGELOG, the docs-sync/commands SKILLs) were flagged as navigable. Now a link is skipped only when the whole match sits inside a backtick span; a link whose *label* is inline-code stays checked (`bin/ai-kit-docs-sync-dead-links.sh`).
  - **`.docs-sync-ignore` path-prefix entries were broken** (`bin/lib/docs-sync-excludes.sh`): the `${line#**/}` glob collapsed `tests/fixtures` → basename `fixtures` (would prune canonical `standards/`), and `awk -v` choked on the newline-joined prefix list (silently dropped every file). Both fixed — `**/` strip now guarded to literal prefixes; prefix filter rewritten in pure bash.
- Added repo `.docs-sync-ignore` excluding non-authored / duplicate trees from ai-kit's self-scan: `.agents/` (third-party installed skills), `tests/fixtures/` (intentional broken links), the synced `workflow/standards` + `workflow/context` mirrors (canonical copies are scanned), and the frozen `docs/roadmap-archive.md`.
- Regression: inline-code-span fixture + assert in the docs-sync test. Full suite 910 passed / 0 failed.

## 1.41.1 — 2026-06-14

### Fixed

- `emit-rules.sh` no longer emits dead cross-reference links (closes #105). "See also" links in `standards/rules/*.mini.md` used `.mini.md`/`.nano.md` suffixes and `../` depths that 404 in the flat emitted layout (`.claude/rules/<name>.md`, `.cursor/rules/<name>.mdc`) — 27 broken links that ai-kit's own `/ai:docs-sync` flagged. New `_emitter_body` (shared lib) rewrites each link against the set of rules actually emitted this run (`$AIKIT_EMITTED_RULES`): a link to an emitted rule → flat `./<name>.<ext>` sibling (ext-aware: `md` for Claude Code, `mdc` for Cursor), filename-style labels de-suffixed; everything else (non-emitted rule, skill, external doc) → unlinked, label text kept. Emitted output now passes the dead-link check (0 broken). Regression: 3 asserts in `tests/bin/cases/bootstrap-emit.sh`.

## 1.41.0 — 2026-06-14

### Added

- `recommend-tools` plugin catalog: `ui-ux-pro-max` (`standards/external/plugins.json`, category `design`) — surfaced for frontend stacks alongside `frontend-design` / `lazyweb`. Genuinely additive: priority-ranked, `--domain`-queryable design-rule database + shadcn MCP (structured token/pattern output, not just critique). Marketplace-clean (`/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`); single-source → surfaced, never default-recommended.

### Changed

- Decision-ledger discipline: `/ai:should-i-use` Ignore verdicts on catalog-eligible tools are now recorded in `standards/external/plugins-excluded.json` instead of evaporating into chat. First entry: `taste-skill` (Leonxlnx/taste-skill) — Ignore (overlaps existing design entries + ui-ux-pro-max; `npx skills add` install doesn't fit the plugin schema; motion/image-board *generation* is out of scope for durable per-project infra).

### Notes

LEAN scope: data-only — two `standards/external/*.json` entries + plugin-copy sync (`bin/sync-plugin-standards.sh`). No scorer/skill code touched. uupm cleared a VETTING.md parity pass with one caveat recorded in its catalog `value`: upstream count claims drift across its own manifests (styles 50+/67, stacks 10/15; README "161 reasoning rules" vs manifest "161 palettes") — capability verified on disk, specific counts treated as advisory.

## 1.40.0 — 2026-05-29

### Added

- `/ai:exploratory-test` skill (closes #97) — captures a long human-driven UI/UX manual review session and bundles findings into one clean parent GH issue per scope. Tester emits 50-100+ free-form findings across roles/apps/pages; skill acks each with one short line (`#N [scope] <one-line>. Gelogd.`), tracks scope-shifts silently, and on end-trigger (`klaar` / `bundel naar github` / EN equivalents) normalizes into an overview table + per-finding repro/expected/actual + cross-references cluster + open-questions section, then creates one parent issue per scope via `gh issue create`. Defaults: capture-only (no diagnose during flow), free-form (no strict template), per-scope bundling (new host → new parent), NL acks (with `--lang en` flag for English). Hands off to `/ai:triage` or `/ai:to-issues` for phase-2. Sibling to `/ai:review` (static-code review) but for human-driven UI/UX review.
- Eval fixture: `tests/eval/prompts/exploratory-test/multi-role-bundle.md` — multi-role / multi-host capture scenario with 9 expectations covering ack format, scope-tracking, label detection, parent-per-scope, body structure, and phase-2 hand-off.

### Notes

LEAN scope: SKILL.md + eval fixture only. No new bin/helpers — the skill is conversational, not deterministic. Defaults come from a proven manual run (naschool#81 / naschool#82, 2026-05-28, 89 findings across 4 roles on 2 hosts). Skill count: 37 → 38.

## 1.39.0 — 2026-05-29

### Added

- Self-host PaaS advisory (closes #20) — Coolify-only v1:
  - `bin/detect-tooling.sh` emits new `deploy` block: `shape` (`serverless` / `self-host` / `mixed` / `unknown`), `serverless_markers`, `self_host_markers`, `coolify_detected`. Serverless markers: `vercel.json`, `netlify.toml`, `wrangler.{toml,jsonc,json}`, `serverless.{yml,yaml}`, SAM templates. Self-host markers: `Dockerfile` + compose pair, or any `.coolify/` / `coolify.{json,yml,yaml}` marker.
  - New catalog `standards/external/paas.json` — Coolify entry (AGPL-3.0, UI-driven, single-host or multi-server). Trade-offs vs Dokku/Caprover/Kamal documented inline. Dokku, Caprover, Kamal deferred to follow-up issues — catalog grows from real adoption signal, not speculation.
  - `bin/recommend-tools.sh` gains `--kind paas`; scorer (`bin/lib/recommend-tools-lib.sh`) honours new `deploy_shape` + `env` signal types.
  - Companion MCP recommendation: Coolify MCP server entry added to `mcp-servers.json` (gated on the same `deploy_shape=self-host` + marker + `COOLIFY_*` env signals). Second-order: pick PaaS first, then optionally wire MCP.
  - `recommend-tools/SKILL.md` + `setup/SKILL.md` Branch 14 wire the new surface; preview-then-confirm trust model — ai-kit never writes Docker/server config without explicit approval.
- Tests: 10 new asserts across `tests/bin/cases/detect.sh` (deploy_shape detection across 5 fixtures + JSON surface) and `tests/bin/cases/recommend.sh` (PaaS scoring on self-host / serverless / `.coolify` marker / `COOLIFY_API_KEY` env). `audit-setup-symmetry.sh` validates paas.json wiring path automatically (no edit needed — generic catalog detection).

### Notes

LEAN scope: Coolify only. Dokku/Caprover/Kamal deferred per the principle that the catalog should grow from validated adoption (the user runs Coolify in production via naschool, hence v1). The `env` signal type added to the scorer is generic — usable by any future catalog entry.

## 1.38.0 — 2026-05-29

### Added

- `/ai:docs-sync` repo-hygiene + dead-links now honour project-local excludes (closes #98, closes #100):
  - Built-in defaults extended with `.pnpm-store`, `phpunit-storage`, `.archive`, `_originals`, `test-results`, `playwright-report`, `.vite-temp`, `coverage`, `.nyc_output`.
  - Active git worktrees (`git worktree list`) are auto-excluded — broken relative paths inside `.agents/worktrees/feat-x/...` stop drowning real findings. Only fires when the project path is the toplevel of its own git repo (no false-positives inside fixtures).
  - New `.docs-sync-ignore` file at repo root (gitignore-style subset): basenames without `/` extend the prune list; entries with `/` extend the path-prefix excludes. Comments + blank lines OK.
- `/ai:recommend-tools` now writes the graphify rule block to **both** `AGENTS.md` and `CLAUDE.md` when `.claude/` is present (closes #99). Prefers `graphify claude install` when the CLI is available; otherwise appends a fenced `<!-- ai-kit:graphify -->` block to `CLAUDE.md`. Auto-loading was the missing half — Claude Code only auto-reads `CLAUDE.md`.

### Removed

- `/ai:handoff` skill (stub since v1.35.0; was scheduled for v1.36.0, slipped). Use `/ai:checkpoint --to tmp` for transfer briefings. Refs cleaned from `docs/mental-model.md`, `docs/eval.md`, and `workflow/context/templates/AGENTS.md.template`. ADR-0009 retained as historical record.

### Notes

LEAN scope: shared exclude logic lives in `bin/lib/docs-sync-excludes.sh`, sourced by both scanners. No new flags, no JSON mode, no per-section opt-out. Test cases added: extra-default-excludes, docs-sync-ignore, git-worktree-exclude. Skill count: 38 → 37.

## 1.37.0 — 2026-05-27

### Added

- `/ai:hygiene` now always prints a `Score: N/100` install-quality grade at the end of the run — even on a fully clean repo (then it just shows "Score: 100/100" with no recipe). When below 100, a ranked "To reach 100:" recipe lists each non-clean section sorted blocker-first with the exact standalone script path to re-run for full detail. Rubric: start at 100, each blocker section −20, each warning section −5, clean 0; floor at 0.

### Notes

LEAN scope: scoring layer lives entirely in `bin/ai-kit-hygiene.sh`. No new flags, no JSON mode, no opt-out. Per-section name + exit code were already captured for the summary block — the scoring loop just sums them. Test (`tests/bin/cases/hygiene.sh`) covers fully-skipped-run-scores-100, real-run-format, and recipe-block-only-when-below-100.

## 1.36.0 — 2026-05-27

### Added

- `/ai:dedupe` Surface 5 now auto-inlines the per-item ecosystem-audit verdict table directly under its section header when `divergent > 0`. No more copying an absolute path and re-running `ai-kit-audit-ecosystem.sh` manually. EXCLUDED count is still surfaced separately above the table. (Closes #86.)
- `docs/auto-classifier-boundaries.md` — names the CC auto-mode classifier boundaries that ai-kit release flows hit (`~/.claude/**` writes; `claude plugin uninstall/install`), the tmpdir-clone workaround, and the "surface the user-runnable command" pattern. Cross-linked from `docs/troubleshooting.md`. (Closes #87.)

### Changed

- `bin/release.sh` tail replaces the one-line "Downstream" hint with an explicit numbered checklist for the user-runnable steps (`/plugin marketplace update`, `/plugin uninstall ai && /plugin install ai@yusufkaracaburun`, `/ai:upgrade` in downstream projects) — these can't run agent-side because the classifier blocks plugin lifecycle commands.
- `workflow/commands/dedupe.md` notes the new auto-inline behaviour so the summariser knows the verdict table is already on screen.

### Notes

`bin/release.sh --bump-marketplace` already encapsulated the tmpdir-clone pattern. This release is documentation + user-facing surfacing — no new primitive needed, the gap was the missing escape-hatch doc + the missing handoff postscript.

## Unreleased

## 1.35.0 — 2026-05-27

### Changed

- **Merged `/ai:handoff` into `/ai:checkpoint` (closes #91, ADR-0009).** One
  skill, one trigger, destination is an argument:
  - `/ai:checkpoint` (default `--to memory`) → same-project, same-machine
    resume; writes to auto-memory; pairs with `/ai:resume`.
  - `/ai:checkpoint --to tmp` → transfer briefing in `$TMPDIR` for another
    agent, machine, or teammate; redaction always-on.
  - `--mid-session` works for either target.
  - `/ai:handoff` slash kept for one release as a deprecation stub
    redirecting to `/ai:checkpoint --to tmp`; removed in v1.36.0.
  - Updated cross-refs in `/ai:resume`, `/ai:onboard`, and
    `standards/rules/context-discipline.mini.md`.
  - Eval prompt `tests/eval/prompts/handoff/mid-migration.md` now targets
    `skill: checkpoint` and asserts `--to tmp` + redaction.
  - Rationale: trigger overlap between the two skills was the actual pain;
    description-sharpening only fixed half. See ADR-0009 for the full
    reasoning and the rejected alternatives.

## 1.34.0 — 2026-05-27

### Changed

- **`/ai:hygiene` repo-skill-hint surfaces both project + framework
  docs-sync (closes #96).** `bin/ai-kit-repo-skill-hint.sh` now sources
  `bin/lib/applicability.sh` and, after listing any project-scoped
  hygiene-style skills under `.agents/skills/`, also surfaces the
  framework `/ai:docs-sync` when applicable (any markdown file present,
  `docs/` exists, or >1 local branch). When both apply, both are listed
  side-by-side with a one-line "use which for what" hint: project skill
  handles repo-specific drift (vocabulary, ADR triggers, status
  tables); framework skill handles universal drift (dead links,
  repo-hygiene, finished-work cleanup). Section stays silent when
  neither source has anything to surface. Tests: 16 asserts cover the
  matrix (both, project-skill-plus-framework, framework-only, neither)
  plus a negative wiring audit confirming the script reuses the
  shared applicability helper instead of duplicating detection.

### Notes

- Out-of-tree follow-up tracked separately: `naschool/.agents/skills/docs-sync/SKILL.md`
  should be slimmed to drop the three generic checks (dead-links,
  repo-hygiene, finished-work cleanup) now that `/ai:docs-sync` covers
  them framework-side. That PR lands in the naschool repo.

## 1.33.0 — 2026-05-27

### Added

- **/ai:docs-sync nudge wiring across checkpoint / ship / triage (closes
  #95).** New shared helper `bin/lib/applicability.sh` exposes
  `is_docs_sync_applicable` (true if `docs/` exists, or any `*.md` file
  is present, or the repo has >1 local branch) and
  `is_hygiene_applicable` (true if `.ai-kit-setup` marker is present).
  New thin wrapper `bin/ai-kit-docs-sync-nudge.sh [path] --context=...`
  prints a context-headed cross-cue ("Before clear, consider:" /
  "Closing this release? Consider:" / "After closing issues, consider:")
  listing the applicable commands; silent when neither applies. The
  three skill bodies now call the helper and surface its output verbatim
  — they never re-implement the applicability logic, so all surfaces
  stay in sync. Tests: 23 asserts cover the applicability matrix
  (docs/, markdown-only, >1 branch, marker, none, both), the three
  context headers, performance (<500ms wall budget for CI noise; <50ms
  target on a typical repo), and a negative wiring audit confirming no
  skill duplicates the helper logic.

## 1.32.0 — 2026-05-27

### Added

- **`/ai:docs-sync` — finished-work section (closes #94).** Detects
  local merged branches and closable GitHub issues. Default-branch
  detection: `git remote show origin` HEAD, falling back to `master`
  then `main`. Default branch, `HEAD`, and the currently-checked-out
  branch are always excluded from the merged-branch list. Closable
  issues come from a strict `(?<![A-Za-z])(?:closes|fixes|resolves)\s+#(\d+)`
  regex against the bodies of the 50 most recently merged PRs — `addresses #N`,
  `see #N`, and `for #N` are deliberately ignored. Fix flow: local
  branch delete is group-confirmable (`git branch -d` refuses unmerged
  as a safety net); remote-branch-delete (`git push origin --delete`)
  and `gh issue close` are **always individual y/N per item** — no
  `--yes-all` or `--batch` flag exists, by design. Skips cleanly on
  non-git repos, when no default branch can be detected, and when `gh`
  is unauthenticated. Tests: 18 asserts cover default-branch detection,
  current-branch exclusion, strict regex (no fuzzy match), no-batch-flag
  source audit, group-confirm accept path, and `--skip-finished-work`.

## 1.31.0 — 2026-05-27

### Added

- **`/ai:docs-sync` — repo-hygiene section (closes #93).** Three
  mechanical `find`-based sub-checks: empty directories (excludes
  `.git`, `node_modules`, `vendor`, `.tmp`, `dist`, `build`, `.next`,
  `.turbo`, `.cache`), broken symlinks (portable detection — no
  GNU `-xtype l`), and orphan `.agents/skills/<name>/` dirs that
  lack a `SKILL.md`. Empty-dir + broken-symlink fixes are
  group-confirmable behind one `y/N` prompt (rmdir + rm). Orphan
  skill dirs are report-only — never auto-deleted, since the dir
  may be in-progress work. `--skip-repo-hygiene` bypasses the
  section. Tests: 29 asserts cover all #93 acceptance criteria,
  including the no-prompt safety path, the accept path (via
  `AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1` test-only env var), and the
  orphan-skill-dir never-deleted guard.

## 1.30.0 — 2026-05-26

### Added

- **`/ai:docs-sync` — standalone content-drift skill (closes #92).**
  Splits content-drift concerns out of `/ai:hygiene` (which stays focused
  on framework wiring health). New driver `bin/ai-kit-docs-sync.sh` runs
  sectioned checks against the project, exits 0 (clean) or 1 (findings).
  First section: **dead-links** — scans every `*.md` for inline
  `[text](path)` links, verifies relative + repo-absolute targets exist on
  disk, and reports `file:line` + missing path per finding. Code fences,
  image links, HTML `<a href>`, bare URLs, external schemes, and anchor-
  only links are deliberately excluded. Anchor fragments are stripped
  before path-existence check (no anchor validation). SKILL.md locks
  6 non-goals (ADR-trigger detection, TODO-completion, status-table
  drift, persona/PII grep, structure-convention, code-comment-as-doc
  parsing) so v2 scope creep gets bounced. Tests: 30 asserts cover all
  acceptance criteria from #92. Follow-up issues #93 / #94 add repo-
  hygiene + finished-work checks; #95 wires nudge integrations; #96
  teaches `repo-skill-hint` to surface both surfaces.

## 1.29.0 — 2026-05-26

### Changed

- **Split `ai-kit-audit-ecosystem.sh` god-script (closes #89).**
  590-LOC dispatcher refactored into 7 sourced libs under
  `bin/lib/audit-ecosystem/` (common, plugins, marketplaces, skills,
  agents, rules, mcp, render). Slim dispatcher (~170 LOC) now only
  handles argument parsing, self-detection, sourcing, and the
  walk → render → exit sequence. Behaviour preserved — all 27
  audit-ecosystem regression tests still pass.

### Added

- **`bin/count-primitives.sh` — single-source primitive counts
  (closes #90).** Emits canonical counts as JSON (default), one-line
  human-readable (`--human`), or drift-check (`--check`). The
  drift-checker greps user-facing docs (`README.md`,
  `docs/architecture.md`, `docs/install-plugin.md`,
  `docs/mental-model.md`, `ONBOARDING.md`, `plugin.json`) for the
  expected count substrings and fails CI when reality diverges from
  any tracked surface. Wired into `.github/workflows/eval.yml` as the
  third eval step. New regression test case `count-primitives` covers
  all three modes + synthetic drift detection (14 asserts).

## 1.28.1 — 2026-05-26

### Fixed

- **Self-audit P0/P1 fixes.** /ai:audit-architecture on ai-kit itself
  surfaced 9 🟠 findings. Quick wins landed inline:
  - **D5 comment-drift on primitive counts.** README, plugin.json,
    docs/architecture.md, docs/install-plugin.md, docs/mental-model.md,
    ONBOARDING.md all synced to reality: 37 skills · 10 commands ·
    30 canonical rules. Root cause (no single source) tracked in
    [#90](https://github.com/yusufkaracaburun/ai-kit/issues/90).
  - **D5 ADR-0004 misleading after v3.0 rename.** Added a Superseded
    banner; the `aikit-` prefix is no longer required — invocation
    is plugin-scoped as `/ai:<skill>` now.
  - **D8 strict-mode rationale comments** on warning-collector scripts
    (`ai-kit-doctor.sh`, `ai-kit-dedupe.sh`, `ai-kit-audit-ecosystem.sh`)
    explaining why `-e`/`-u` are intentionally omitted.
  - **D4 empty `.planning/`** directory removed.
  - Bigger lifts deferred: god-script split
    ([#89](https://github.com/yusufkaracaburun/ai-kit/issues/89)),
    single-source primitive counts
    ([#90](https://github.com/yusufkaracaburun/ai-kit/issues/90)).

## 1.28.0 — 2026-05-26

### Added

- **`/ai:audit-architecture-shadcn` extension.** New
  `workflow/skills/audit-architecture-shadcn/SKILL.md` adds 6
  shadcn/ui-specific heuristics (S1-S6: `cn()` merge discipline, `cva()`
  variant extension, `forwardRef` contract on primitives, deep-relative
  import-path drift away from declared aliases, cross-primitive coupling
  inside `components/ui/`, `components.json` alias drift). Auto-loads
  alongside the React extension when `components.json` declares the
  `https://ui.shadcn.com/schema.json` schema (detected via the new
  `shadcn` framework key in `bin/lib/detect-lib.sh`).

## 1.27.0 — 2026-05-26

### Changed

- **`autonomous` skill promoted out of SPIKE.** Multiple real-queue
  drains in `ai-kit` and `naschool` validated the cold-start /
  fresh-context invariant + `progress.txt` discipline; no contract
  changes versus the spike draft. README "Experimental" row replaced
  by "Automation"; spike doc preserved at
  `docs/spikes/aikit-autonomous-ralph.md` with a PROMOTED banner.

### Added

- **`/ai:audit-architecture-nextjs` extension.** New
  `workflow/skills/audit-architecture-nextjs/SKILL.md` adds Next.js
  App-Router-specific heuristics (server/client boundary, `use server`
  payload safety, RSC streaming + caching, route handler typing,
  middleware scope, `next/image` + `next/font` discipline). Auto-loads
  alongside the React extension via
  `bin/audit-extension-loader.sh` when a `next.config.{js,mjs,ts}` or
  Next dependency is present.

- **CI workflow for eval-suite.** New `.github/workflows/eval.yml`
  runs `tests/bin/eval-structure.sh` and
  `bin/eval-golden.sh --validate-all` as a dedicated job on push to
  `master` and on PRs. Provides external visibility into eval-suite
  health (structural + rubric) and gates regressions before merge.

## 1.26.0 — 2026-05-26

### Added

- **`/ai:hygiene` — memory-audit now scans every typed subdir of
  `.agents/memory/`** (typically `feedback/`, `reference/`, `decisions/`,
  `patterns/`, `project/`), not just `feedback/`. Orphan + stale logic is
  identical per bucket; `README.md` index files are ignored. Output names
  the buckets it scanned so the user sees coverage at a glance.

- **`/ai:hygiene` — repo-skill-hint section.** New
  `bin/ai-kit-repo-skill-hint.sh` lists project-scoped skills under
  `.agents/skills/` whose name or description matches hygiene-style
  triggers (docs-sync, doc-drift, repo-hygiene, housekeep, prune,
  cleanup, audit). The hint points at `/skill-name` instead of
  duplicating repo-specific content in ai-kit. Wired into
  `bin/ai-kit-hygiene.sh` as section 5 with `--skip-repo-skills` flag.
  Report-only; skips silently when no `.agents/skills/` exists.

## 1.25.0 — 2026-05-26

### Added

- **`/ai:hygiene` — memory-audit section.** New `bin/ai-kit-memory-audit.sh`
  scans `.agents/memory/feedback/*.md` for ORPHAN entries (not indexed in
  `.agents/memory/MEMORY.md`) and STALE entries (>90d untouched + 0 refs).
  Wired into `bin/ai-kit-hygiene.sh` as the 4th section with `--skip-memory`
  flag. Report-only; skips silently when no `.agents/memory/feedback/`
  directory exists.

- **`/ai:audit-architecture` per-stack extensions — v1 big-bang** (EPIC
  [#35](https://github.com/yusufkaracaburun/ai-kit/issues/35), ADR-0008).
  The stack-agnostic audit skill now auto-loads stack-specific extensions
  via `bin/audit-extension-loader.sh` whenever a matching framework or
  language is detected.

  Three extensions land in this release, each shipping a triplet (skill +
  rule + helper-script + fixture):

  - **`audit-architecture-laravel`** ([#80](https://github.com/yusufkaracaburun/ai-kit/issues/80))
    — 22 strict heuristics across the 9 audit dimensions. Always-on
    strict mode (severity floor 🟡; API findings L13-L18 floor at 🟠).
    Detects `api-only` vs `full-stack` mode via `routes/api.php` +
    Inertia/Livewire/Blade markers. Helper-script gates Larastan,
    `composer outdated`, `php artisan about`.
  - **`audit-architecture-react`** ([#81](https://github.com/yusufkaracaburun/ai-kit/issues/81))
    — 8 React 19 heuristics, including the RSC server/client boundary
    leak (R6) and React 19-specific server-action typing (R7). Default
    strictness. Helper-script gates ESLint + `tsc --noEmit`. Matches
    `react`, `nextjs`, `remix`.
  - **`audit-architecture-typescript`** ([#82](https://github.com/yusufkaracaburun/ai-kit/issues/82))
    — 8 framework-agnostic language-level heuristics (any-leak,
    as-cast-past-edge, exhaustive-switch, decorator/runtime,
    duplicated-type-alias, unused-type-export, readonly drift,
    overloads-as-discriminated-union). Fires alongside React/Vue/Next
    extensions. Helper-script gates `tsc --noEmit --strict`
    (force-strict regardless of project tsconfig), `ts-prune`, ESLint
    `@typescript-eslint/strict` subset.

  Total v1 surface: 38 new heuristics encoded as `.mini.md` rules. The
  React + TypeScript ownership boundary is enforced by the shared
  `tests/fixtures/audit-react-ts-overlap/` fixture (each finding row
  appears exactly once across `[react]` and `[typescript]` prefixes).

  Flutter extension ([#83](https://github.com/yusufkaracaburun/ai-kit/issues/83))
  is deferred to v2 pending a real Flutter project.

  New env vars:

  - `AI_KIT_AUDIT_NO_EXTEND=1` — skip extension loading entirely; run
    vanilla baseline audit.
  - `AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack` — override
    detected mode for the Laravel extension.

  See `docs/adr/0008-audit-architecture-extensions.md` for the twelve
  design decisions frozen during the 2026-05-26 grilling session, and
  `standards/contracts/audit-architecture-extension.contract.md` for
  the contract every future extension must satisfy.

## 1.24.0 — 2026-05-26

### Added

- **Canonical feedback-rules layer** (#30, ADR-0007). New
  `standards/rules/feedback/` subdir under canonical rules, emitted by
  default at `/ai:setup` so every new project inherits cross-project
  workflow / style / tool-gotcha defaults instead of re-discovering
  them per project. v1 set (all `universal: true`):
  `phase-scope-discipline`, `branch-cleanup-after-merge`,
  `deployment-on-demand`, `minimal-comments`, `latest-stable-deps`
  (defers to `project-lifecycle` for production phase),
  `mark-recommended-option`, `bsd-sed-word-boundary`,
  `gitignore-public-assets-trap`. Emitter recursion patched into
  `bin/emit-rules.sh`, `bin/lib/recommend-lib.sh`,
  `bin/ai-kit-audit-ecosystem.sh`, `bin/ai-kit-dedupe.sh` so
  feedback-rules are first-class to every downstream consumer.
  `/ai:setup` Branch 12 and `/ai:recommend-rules` Phase 1 name the
  feedback bucket explicitly. `standards/promotion-quorum.md` gains a
  sibling section documenting the manual feedback-rule promotion flow
  (ai-kit-lessons → GH issue → curate during release).

- **`/ai:upgrade` prints CHANGELOG slice between versions.** After
  re-stamping `.ai-kit-setup`, the script slices the relevant
  CHANGELOG section between the old marker version and the new one
  and prints it so the user sees what changed across the upgrade
  without cracking open CHANGELOG.md. Silent skip on same-version /
  unknown-old / missing CHANGELOG / no matching headings.

### Fixed

- **Plugin packaging shipped no `context/`** — `setup-gh-workflow.sh`,
  `bootstrap-project.sh`, `apply-docker.sh`, and several skills
  resolve templates / prompts via `$AI_KIT_ROOT/context/**`, and the
  cached plugin install hard-exited with `Templates missing:
  <root>/context/templates/github` (or silently skipped: PR-template
  scaffold, Docker apply). Root cause: ai-kit had no mirror script
  for `context/` and the release flow never sync'd `standards/`
  either. Fix: new `bin/sync-plugin-context.sh` mirror script,
  symmetric to the existing sync-plugin-{bin,hooks,standards}; release
  flow now calls both `sync-plugin-standards.sh` and
  `sync-plugin-context.sh`. Three new asserts in `structure.sh` lock
  the invariant. Doctor's "PR template missing — run
  /ai:setup-gh-workflow" warning no longer chases a dead link.

### Docs

- `bin/setup-gh-workflow.sh` header comment listed only steps 1–4
  (issue templates, workflows, labels, project board) — the script
  also scaffolds the PR template (step 5) and applies branch
  protection (step 6) since #66. Docblock now in sync.

### Tests

- `tests/bin/cases/release-install.sh`: `which --list` skill-count
  assert bumped from 30 → 32 (audit-fix + doc-to-skill landed in
  v1.23.0 without bumping the hardcode).
- `tests/bin/cases/structure.sh`: skill-count assert bumped from 30
  → 32; three new asserts cover `sync-plugin-standards --check`,
  `sync-plugin-context --check`, and
  `workflow/context/templates/github` presence in the plugin tree.
- `tests/bin/cases/bootstrap-emit.sh`: `--list` count assert bumped
  from 26 → 34 to cover the eight new feedback-rules.
- `tests/eval/prompts/audit-fix/finding-a1.md` and
  `tests/eval/prompts/doc-to-skill/pdf-to-scaffold.md`: missing eval
  scenarios added so `eval-structure` is clean again.

Test suite: 585 / 585 green.

## 1.23.0 — 2026-05-26

### Added

- **`/ai:audit-fix` skill** (#34) — consumes `/ai:audit-architecture`
  reports and applies atomic per-finding fixes. One commit per
  finding, per-finding user approval (or `--batch` with severity
  filter), affected-paths-only scope, scoped verification before
  commit, read-after-write re-run on the dimension, report row
  rewritten to `✅ fixed` with closing commit SHA. Refusal cases for
  scope-creep, bundling, missing fields, and behaviour-change risk.
- **`/ai:doc-to-skill` skill + `bin/doc-to-skill.sh`** (#45) — converts
  a single PDF / EPUB / DOCX / RTF / ODT / MD into a `SKILL.md`
  scaffold with frontmatter, claim placeholders, chapter index from
  source headings, sources list, and provenance credit to
  `virgiliojr94/book-to-skill` (MIT). Pure bash + pandoc — pandoc is a
  system dep, not added to the repo. Defaults output path to
  `workflow/skills/` when run inside ai-kit, `./skills/` in consumer
  repos. Refuses to overwrite an existing `SKILL.md`.

### Fixed

- **#26 closed** as already-shipped — Tier 1 path-pattern triggers in
  `bin/hooks/context-drift-check.sh` landed in commit `3a64907` ahead
  of this triage pass. Issue verified against AC; no new code needed.

## 1.22.0 — 2026-05-26

### Added

- **Promotion quorum for recommend-\*** (#46). New
  `standards/promotion-quorum.md` codifies the ≥2-independent-sources
  bar a community rule / tool / pattern must clear before
  `/ai:recommend-rules` or `/ai:recommend-tools` marks it as default-on.
  Single-source entries are still surfaced — labeled `(sources: 1 —
  preview only)` and never pre-selected. Both recommend-\* SKILL.md
  surfaces reference the doc and carry the annotation contract with
  worked examples.

### Changed

- **`/ai:autonomous` step 0** gains three preflight checks adopted from
  the OpenHands research arc (#21):
  - Per-conversation `AI_KIT_ROOT` pinning from the Agent Brief's
    `ai_kit_root:` key (falls back to existing resolver).
  - Triage-labels-exist precondition: refuses to drain when the
    `ready-for-agent` label is missing on the tracker.
  - Per-project merge-policy detection (brief → `.ai-kit-setup` → git
    config → default `pr`). Brief-vs-project disagreement halts via new
    `exit-gate merge-policy-mismatch`.
  New event family `preflight-*` lands in the `progress.txt` schema so
  the cold-readable log shows step 0 ran clean before the first `pick`.

### Docs

- **`docs/spikes/aikit-autonomous-ralph.md`** — new section "Research
  input: OpenHands patterns". 6-row comparison table mapping
  `All-Hands-AI/OpenHands` patterns (sandbox-per-session, status state
  machine, event store, workspace-volume per id, no-autonomous-picker,
  pre-flight phases as first-class) to the three spike contract gaps,
  with adopt / adopt-with-modification / reject decisions per pattern.

## 1.21.0 — 2026-05-26

### Added

- **/ai:setup Tier-A Branch 2c — Universal MCPs auto-prompt** (#51). MCP
  servers marked `universal: true` in `standards/external/mcp-servers.json`
  (today: `context7`; future-proof for more) are now auto-prompted during
  Tier-A setup instead of waiting for a `/ai:recommend-tools` follow-up.
  Per-tool prompt, never silent install. Idempotent: a new
  `--universal-mcps-prompted=...` flag on `bin/write-setup-marker.sh`
  accumulates handled names in `.ai-kit-setup` so re-runs skip them. Adding
  a new `universal: true` entry to the MCP catalog is picked up
  automatically — no skill-body edit required.
- **Catalog: three new plugin entries in `standards/external/plugins.json`**
  (#42 #43 #44):
  - `context7@claude-plugins-official` — live library docs MCP, pairs with
    the canonical context7 rule.
  - `claude-code-setup@claude-plugins-official` — general-purpose Claude
    Code automation recommender; complementary to `/ai:setup` and
    `/ai:recommend-tools`.
  - `caveman@caveman` (JuliusBrussee/caveman) — ultra-compressed
    communication mode + subagent-output compression.

  All three carry `universal: true`. `bin/ai-kit-audit-ecosystem.sh` now
  reports each as OWNED instead of ADOPT-divergent.

### Changed

- `standards/external/companions.json`: context7's `tiers[0]` entry gains
  `auto_prompted: true` and a wiring pointer to `setup/SKILL.md` Branch 2c
  so `bin/audit-setup-symmetry.sh` stays consistent with the new auto-prompt
  flow.

## 1.20.3 — 2026-05-25

### Added

- **2-dev default sweep ([#52](https://github.com/yusufkaracaburun/ai-kit/issues/52))** — ai-kit defaults now assume ≥2 devs (writer + reviewer) instead of solo. Eight slices merged under one parent:
  - `setup-gh-workflow` ([#66](https://github.com/yusufkaracaburun/ai-kit/issues/66)): hybrid `gh api PUT` branch-protection (403 → checklist fallback, exits 0); scaffolds `.github/PULL_REQUEST_TEMPLATE.md` with DoR/DoD checkboxes; new `--no-protection` / `--no-pr-template` flags; `--dry-run` emits payload + fallback command.
  - `triage` + `to-issues` ([#65](https://github.com/yusufkaracaburun/ai-kit/issues/65)): explicit "Second-dev cold-pickup" rule pointing to #52.
  - `tdd` ([#63](https://github.com/yusufkaracaburun/ai-kit/issues/63)): new "Review (required)" phase with single-human-project clause.
  - `ship` ([#63](https://github.com/yusufkaracaburun/ai-kit/issues/63)): review-before-merge stated as precondition, not recommendation.
  - `autonomous` ([#68](https://github.com/yusufkaracaburun/ai-kit/issues/68)): Trust-model gains explicit "Agent is the writer; the reviewer is human" rule with solo-human caveat.
  - `setup` + `onboard` ([#62](https://github.com/yusufkaracaburun/ai-kit/issues/62)): two surviving team-size "solo" hits rewritten in 2-dev framing. Install-layout `setup_mode=solo-*` vocabulary preserved.
  - AGENTS.md / CLAUDE.md templates ([#64](https://github.com/yusufkaracaburun/ai-kit/issues/64)): new "Team shape" section documents the "we" / 2-dev default.

- **`/ai:doctor` single-dev drift checks ([#69](https://github.com/yusufkaracaburun/ai-kit/issues/69))** — three new warn-only checks in GitHub repos: PR template missing, branch-protection off (skipped on 403 / non-admin), single-committer in last 30d (gated on ≥5 commits). All warn (never error). `/ai:hygiene` inherits via its existing doctor call.

- **`/ai:doctor` workflow-text solo lint ([#70](https://github.com/yusufkaracaburun/ai-kit/issues/70))** — regression guardrail across `workflow/skills/**/*.md` + `workflow/commands/**/*.md`. Locks the baseline at zero team-size solo/single-dev hits. Whitelists install-layout vocab, rule-discussion idioms (`solo-human`, `single-dev shortcut`), and per-line `solo-lint:allow` directive.

### Fixed

- **`recommend-tools` companions disambig ([#53](https://github.com/yusufkaracaburun/ai-kit/issues/53))** — `graphify-wiki` (AST-derived at `graphify-out/wiki/`) and `llm-wiki` (curated at `wiki/`) now name themselves uniquely; glue templates carry a disambig footer; `companions.json` cross-refs both ways; `recommend-tools` SKILL emits a "Two wikis present" block in AGENTS.md when both companions are wired.

### Audited

- **`recommend-tools` solo-heuristic audit ([#67](https://github.com/yusufkaracaburun/ai-kit/issues/67))** — grep across `workflow/skills/recommend-tools/` + scorer + JSON catalogs returned zero hits. recommend-tools already scores per stack-signal; no team-size heuristics existed to drop. Closed with evidence comment, no code change.

### Tests

- Total assert count: 506 → 575 (69 new). New test cases: `companions-disambig` (7), `we-pronouns` (4), `setup-gh-workflow-protection` (14), `setup-onboard-no-solo` (7), `cold-pickup-rule` (8), `autonomous-writer-reviewer` (6), `tdd-ship-review-required` (9), `single-dev-drift` (15), `doctor-workflow-solo-lint` (10).

## 1.20.2 — 2026-05-25

Patch: `ai-kit-audit-ecosystem.sh` now surfaces deliberately-excluded plugins
with a dedicated `EXCLUDED` verdict instead of conflating them with `REPLACE`
(which is reserved for user-scope skill/agent shadowing). The audit's
`--converge` mode emits a `/plugin uninstall` command per EXCLUDED finding
with the recorded alternative from `standards/external/plugins-excluded.json`,
and `/ai:dedupe` Surface 5 calls out the EXCLUDED count distinctly so
`/ai:hygiene` inherits the signal.

Before: an installed superpowers (or any other excluded plugin) was emitted
as `REPLACE` next to user-scope skill/agent shadowing. The plugins-excluded
catalog knew the plugin shouldn't be there, but the verdict was lossy.

After: `verdict: "EXCLUDED"` carries the recorded reason verbatim, the
converge recipe prints the uninstall command, and the dedupe summary states
"N EXCLUDED plugin(s) installed — ai-kit ships equivalents, uninstall
suggested." Trust-model unchanged — never auto-uninstalls.

- **Fix** `bin/ai-kit-audit-ecosystem.sh`: emit `EXCLUDED` (was `REPLACE`) for
  plugins matching `plugins-excluded.json`; counted as divergent; new converge
  case for `plugins/EXCLUDED` surfaces uninstall + alternative hint.
- **Fix** `bin/ai-kit-dedupe.sh`: extract `ECOSYSTEM_EXCLUDED` from ecosystem
  JSON; Surface 5 prints a distinct EXCLUDED line when present.
- **Docs** `workflow/commands/dedupe.md`: extend Surface 5 verdict-token list
  with `EXCLUDED`; tighten `REPLACE` meaning to user-scope shadowing only.
- **Tests** `tests/bin/cases/audit-ecosystem.sh` + `tests/bin/cases/dedupe.sh`:
  new assertions for verdict, divergent counting, converge output, and human
  surfacing via real-catalog HOME-override fixture.
- **Chore** Re-sync `workflow/bin/` from `bin/` (pre-existing drift on
  `audit-setup-symmetry`, `bootstrap-project`, `emit-agents`, `eval-skill`,
  `install-global`, `lib/detect-lib`).

Closes [#54](https://github.com/yusufkaracaburun/ai-kit/issues/54).

## 1.20.1 — 2026-05-25

Patch: `emit-rules.sh` now resolves the ai-kit version via the shared
`resolve_ai_kit_version` helper (with `plugin.json` fallback) instead of
requiring a `VERSION` file at the script's parent root. Plugin installs
ship the `workflow/` subdir without `VERSION` at top level, so the old
hard-coded read failed with `ai-kit VERSION file missing` and exit 2 —
blocking `/ai:recommend-rules` Phase 3 emit and any direct
`emit-rules.sh` call on a plugin-only install.

- **Fix** `bin/emit-rules.sh` + `workflow/bin/emit-rules.sh`: use
  `resolve_ai_kit_version "$AIKIT"`, same migration the other bin/
  scripts already had (`verify-setup.sh`, `ai-kit-upgrade.sh`,
  `ai-kit-doctor.sh`, `ai-kit-status.sh`).

Closes [#55](https://github.com/yusufkaracaburun/ai-kit/issues/55).

## 1.20.0 — 2026-05-25

### Added

- **`branches.lifecycle` in `.ai-kit-setup`** — new orthogonal signal (`development` | `production`) calibrates default agent caution per project lifecycle phase. Missing key defaults to `production` (safe-by-default, no regression for existing installs). Closes [#56](https://github.com/yusufkaracaburun/ai-kit/issues/56), [#58](https://github.com/yusufkaracaburun/ai-kit/issues/58).
- **`standards/rules/project-lifecycle.mini.md`** — new canonical rule (universal=true, always-on, weight=high). Emits a 5-axis behaviour contract (schema migrations / backwards-compat / defensive code / destructive ops / feature flags) with both columns visible so the LLM can calibrate edge cases. Lands in `.claude/rules/project-lifecycle.md` + `docs/agents/active-rules.md` via the existing emit-rules pipeline.
- **`bin/write-setup-marker.sh --lifecycle=development|production`** — new flag persists the phase in the marker. Rejects invalid values with exit 2 + clear error.
- **`/ai:setup` Branch 2b** — Tier-A lifecycle prompt; default `development` for fresh greenfield, `production` for brownfield setup-mode. Re-runs follow the existing keep/change/skip pattern. Closes [#59](https://github.com/yusufkaracaburun/ai-kit/issues/59).
- **`/ai:phase <development|production>`** — new lightweight skill flips the lifecycle key without re-running `/ai:setup`. No-arg form prints the current phase. Surfaces the script's `lifecycle: <old> → <new>` transition + restart-Claude-Code reminder verbatim — the canonical rule reloads only on next session. Closes [#60](https://github.com/yusufkaracaburun/ai-kit/issues/60).
- **`/ai:status`** — surfaces `lifecycle=<value>` alongside the existing branch summary, with the same `// "production"` fallback.

### Tests

- `tests/bin/cases/structure.sh` bumped to 30 skills / 10 slash commands; the per-command loop now covers `phase`.
- `tests/bin/cases/release-install.sh` bumped `which --list` row count to 30.
- `tests/bin/cases/bootstrap-emit.sh` bumped `emit-rules --list` row count to 26.
- `tests/eval/prompts/phase/flip-to-production.md` — new eval fixture covering invoke-the-script / don't-re-run-setup / surface-transition+reminder / reject-invalid-without-retry / read-marker-not-guess.

## 1.19.0 — 2026-05-25

### Added

- **`/ai:rename-housekeeping <old> <new>`** — new skill that rewrites stale absolute-path references in memory files after a local repo rename or move. Scans `~/.claude/CLAUDE.md`, project `CLAUDE.md`/`AGENTS.md`/`.agents/memory/**`/`.planning/**`/`docs/**`/`.claude/**`, and `~/.cursor`/`~/.codex`/`~/.gemini`. Dry-run preview → confirm → snapshots every `~/.claude/**` target to `~/.claude/.backups/<ts>/` before write → updates `~/.claude/known-projects.json`. Closes [#33](https://github.com/yusufkaracaburun/ai-kit/issues/33).
- **`bin/hooks/rename-detector.sh`** — user-global `SessionStart` hook that maintains `~/.claude/known-projects.json` (`name`, `path`, `first_seen`, `last_seen`). Emits a one-line nudge only when `basename($PWD) == known.name && $PWD != known.path && ! test -d known.path`. Multi-clone case (both paths still on disk) stays silent and registers a disambiguated second entry.
- **`bin/install-rename-hook.sh`** — idempotent installer that wires the hook into `~/.claude/hooks/` and non-destructively merges a `SessionStart` entry into `~/.claude/settings.json`. Refuses to overwrite malformed JSON. `--uninstall` cleanly reverses both.
- **`/ai:setup` Branch 11b** — "install global rename-detector?" one-line prompt; gated on whether the hook is already wired.

### Tests

- `tests/bin/cases/rename-housekeeping.sh` adds 30 assertions across structure, fake-rename, known-projects-update, hook-rename, multi-clone-guard, installer idempotency, and corrupt-`settings.json` refusal.
- `tests/eval/prompts/rename-housekeeping/post-mv.md` eval fixture closes the missing-fixture warning.

## 1.18.2 — 2026-05-25

Patch: context7 detection now catches plugin-provided installs (not
just user-scope MCPs).

Live incident on 2026-05-25 in a fresh session: ai-kit ran
`claude mcp list | grep -q context7`, saw nothing, told the user
"NOT_INSTALLED", then `claude mcp add --scope user context7` — but
the `context7@claude-plugins-official` plugin was already installed
and providing the same MCP. Result: `/doctor` reported
"MCP server context7 skipped — same command/URL".

Root cause: `claude mcp list` only shows user-config MCPs and
currently-connected plugin MCPs. Plugin-provided MCPs that aren't
active in the current project are invisible. Detection must check
both surfaces.

- **Fix** `standards/external/companions.json` → context7 entry: detection
  now checks both `claude mcp list` AND `claude plugin list`; new
  `conflicts[]` entry warns about the plugin-vs-user-scope clash;
  install block names the plugin path as preferred.
- **Fix** `standards/external/mcp-servers.json` → context7 entry: new
  `install_paths` block documenting preferred plugin path, fallback
  user-scope command, correct detection one-liner, and a conflict_note.
- **Fix** `workflow/skills/recommend-tools/SKILL.md` Phase 1 detection
  now emits a context7 line that combines both checks before
  recommending anything.

## 1.18.1 — 2026-05-25

Patch: ship `bin/ai-kit-hygiene.sh` + updated `bin/audit-setup-symmetry.sh`
in the plugin install.

v1.18.0 added the script + symmetry-audit changes to repo-root `bin/`
but skipped `bin/sync-plugin-bin.sh`, so `workflow/bin/` (the
plugin-install source) never received the files. `/ai:hygiene` resolved
`${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-hygiene.sh` to a non-existent path on
every install.

- **Fix** `workflow/bin/ai-kit-hygiene.sh` — now mirrored from
  `bin/ai-kit-hygiene.sh`.
- **Fix** `workflow/bin/audit-setup-symmetry.sh` — re-synced so the
  recommend-tools/SKILL.md wiring-path check ships in the plugin.

Process gap that allowed this: the release flow has
`bin/sync-plugin-bin.sh --check` available but the manual commit path
did not invoke it. Adding a pre-commit guard for `workflow/bin/` drift
is a follow-up.

## 1.18.0 — 2026-05-25

Minor: one-shot hygiene command + companion-tool catalog + graphify
wiki tier + llm-wiki conflict-detection.

### `/ai:hygiene` — one-shot housekeeping

ai-kit shipped three separate housekeeping scripts (`ai-kit-doctor.sh`,
`ai-kit-dedupe.sh`, `audit-setup-symmetry.sh`) but no chat-callable
aggregator. Users had to remember each script and run them one by one.
The drift-check hook auto-fires on Edit/Write in client repos, but
install-health, duplicate detection, and catalog-symmetry have no
auto-trigger anywhere.

- **New** `bin/ai-kit-hygiene.sh` — orchestrates doctor + dedupe +
  audit-setup-symmetry in sequence with section headers; exit code =
  max of the three (0 clean, 1 warn, 2 block). Skip flags:
  `--skip-doctor`, `--skip-dedupe`, `--skip-symmetry`.
- **New** `/ai:hygiene` slash command — wraps the script and summarises
  per-section findings with routing hints (`/ai:setup`,
  `bin/sync-plugin-version.sh`, `/ai:dedupe --fix`, …). Reports only;
  never deletes.

### `standards/external/companions.json` — companion catalog

The four companions (graphify, caveman, llm-wiki, context7) lived as
hard-coded prose inside `recommend-tools/SKILL.md`. New companions
could not be added without editing the skill body, and
`audit-setup-symmetry.sh` had no signal to flag missing wiring paths.

- **New** `standards/external/companions.json` — vendored catalog
  documenting each companion's tiers, detection signals, glue files,
  and conflict checks. Same provenance frontmatter pattern as the
  other `standards/external/*.json` tables.
- **Updated** `bin/audit-setup-symmetry.sh` — recognises a third
  wiring path: `workflow/skills/recommend-tools/SKILL.md` (companions
  branch, non-scored judgement-based recommendations). Companions
  failing to reference their catalog entry will block setup-symmetry
  audit.
- **Updated** `recommend-tools/SKILL.md` — references the catalog as
  source of truth; per-companion behaviour now derives from the JSON.

### `graphify --wiki` opt-in tier + post-run nudge

graphify supports `graphify . --wiki` (AST-only, no LLM cost) — a
generated Markdown wiki under `graphify-out/wiki/` that beats per-query
subgraphs for symbol-lookup navigation. The flag was undocumented in
ai-kit; users never knew to consider it.

- **Updated** `recommend-tools/SKILL.md` Phase 1 (Detect) — emits a
  separate line for the wiki tier so the recommendation can branch on
  presence/absence.
- **Updated** `recommend-tools/SKILL.md` Phase 3 (graphify branch) —
  adds step 5 documenting the opt-in tier with an explicit decision
  rule: recommend only when the user asks, the repo is large, or the
  recent transcript shows >3 grep/find calls for symbol locations.

### `llm-wiki` conflict-detection with existing `docs/`

llm-wiki scaffolded `wiki/` + `raw/` without checking whether the
project already had a curated `docs/` tree. The agent risked "helpfully
consolidating" existing docs into the wiki — eroding the boundary
between human-curated material (`docs/`) and agent-derived material
(`wiki/`).

- **Updated** `recommend-tools/SKILL.md` Phase 3 (llm-wiki branch) —
  adds an explicit Conflict-check step 1: surface the warning from
  `companions.json` verbatim before scaffolding; the agent must never
  relocate, rewrite, or "consolidate" files under existing `docs/`
  into `wiki/`. AGENTS.md pointer block now spells out the
  docs/ ↔ wiki/ boundary explicitly when both coexist.

## 1.17.1 — 2026-05-25

Patch: ship a starter `.graphifyignore` with the graphify companion.

Without an ignore list, `graphify .` scans `node_modules/`, `vendor/`,
build outputs, lockfiles, binary assets, and recursively
`graphify-out/` itself — producing a junk-laden graph on any real
Laravel / Node / Vite repo. Users had to discover this and write an
ignore file by hand after the first run.

- **New** `context/templates/companions/graphifyignore` — 84-line
  starter list covering PHP/Laravel (`vendor/`, `backend/storage/`,
  `backend/bootstrap/cache/`, …), Node/pnpm (`node_modules/`,
  `.pnpm-store/`), build outputs (`dist/`, `.next/`, `.vite/`, …),
  IDE/OS dirs, agent scratch (`.agents/worktrees/`,
  `.claude/tdd-guard/`, …), lockfiles, binary assets, logs, and
  `graphify-out/` itself. Stack-agnostic + common monorepo
  `backend/*` paths — lines for absent paths are no-ops.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — Phase 3
  graphify gains a new step 3: copy template to project root as
  `.graphifyignore`, **skip if present** (never clobber a project's
  own ignore list). Phase 4 "Wired" line mentions `.graphifyignore`
  when newly written.
- **Updated** `context/templates/companions/README.md` — table row
  for the new glue file.
- **Updated** `context/templates/companions/graphify.md` — one extra
  AGENTS.md rule line: "tune `.graphifyignore` at the project root
  before the first `graphify .` run".

Trust posture unchanged: ai-kit writes glue, never auto-runs
`graphify .`. User still triggers init themselves.

## 1.17.0 — 2026-05-25

Closes #50 (subagent recommendations) and #48 (setup-symmetry lock).
Closes #49 retroactively — verified that `standards/external/plugins.json`
was already wired via the `recommend-tools` scorer from v1.12.x; the
issue scope (separate `recommend-plugins` skill) would have duplicated
~80% of `recommend-tools` plumbing. Branch 14 (#19, v1.16.0) already
surfaces plugins through `recommend-tools.sh --kind plugin`.

The remaining work: extend the same recommend-tools surface to subagents
and lock the symmetry principle so future catalogs cannot land without
a wiring path.

- **New** `standards/external/subagents.json` — initial entries:
  `claude-code-guide` (universal docs subagent), `caveman:cavecrew-
  investigator` / `cavecrew-builder` / `cavecrew-reviewer`. Schema
  mirrors `plugins.json` with additional `parent_plugin` (install
  pointer) + `tools` (trust-surface disclosure) fields. Built-in
  subagents and ai-kit's own subagents are explicitly excluded from
  the catalog — see `_meta.notes`.
- **Updated** `bin/lib/recommend-tools-lib.sh` — fourth `emit()` call
  for `subagents.json`, silent skip when absent (older clones). Sort
  key unchanged (score desc, kind, name).
- **Updated** `bin/recommend-tools.sh` — `--kind subagent` filter and
  usage doc.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — Extended
  section covers four catalogs (was three); trust-model bullet
  documents subagent-specific surface (parent_plugin install + tools
  list disclosure).
- **New** `bin/audit-setup-symmetry.sh` — enumerates
  `standards/external/*.json` and asserts each is wired via the
  scorer lib OR explicitly mentioned in `setup/SKILL.md`. Hard-coded
  exclusions: `plugins-excluded.json`, `VETTING.md`. Fails with
  pointer to #48 on mismatch.
- **Updated** `tests/bin/cases/apply-marker.sh` — 3 new assertions
  invoking `audit-setup-symmetry.sh`.
- **Updated** `tests/bin/cases/recommend.sh` — `kind` enum widened to
  `{mcp,hook,plugin,subagent}`; new assertion verifies
  `claude-code-guide` subagent surfaces and `--kind subagent` filter
  returns only subagent rows. 464/464 total pass (was 459).

The symmetry-audit lock means new catalogs added to
`standards/external/` MUST either be picked up by the scorer
(`emit()` call) or get their own setup branch — otherwise CI fails.
Closes the #48 DoD.

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
