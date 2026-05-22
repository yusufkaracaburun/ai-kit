# Roadmap

Forward-looking work. Not commitments — directions. ADRs land here once decided.

## 1. Agent-agnostic refactor

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
- [ ] **Open:** broader migration guide in `docs/troubleshooting.md` for non-emeq legacy installs.

---

## 2. Project-aware rule recommendation (with optional web search)

**Status:** **landed** 2026-05-22. Canonical scorer + frontmatter schema + skill scaffolding done. The vendoring flow is now exercised end-to-end — `standards/rules/external/laravel-php-83.mini.md` is the first web-vendored rule, pinned by SHA. `/aikit-recommend-rules` is wired into `/aikit-setup` as Tier B Branch 12. Only web-search caching remains open.

**Problem.** Today, bootstrap *used to* emit all 7-9 ai-kit book rules to every project regardless of stack. A Laravel monolith and a React+Vite SPA got identical rules. That's noise — refactoring/legacy-code rules are valuable for a 10-year-old codebase, less so for a greenfield prototype. Worse: ai-kit has no awareness of *stack-specific* community rules that already exist (Laravel Boost rules, Next.js conventions, Rails idioms, Django patterns).

**Direction.** A new step in `/aikit-setup` (or standalone `/aikit-recommend-rules` skill) that:

1. **Reads detection.** `detect-tooling.sh --json` → frameworks, package manager, language, architecture, repo age (commit count / first-commit date).
2. **Scores canonical rules.** Mapping table: `legacy-code` → high score for repos with >2y history; `ddd-distilled` → high for backend-with-domain-folders; `release-it` → high for repos with deployment config; `aposd` → universal; `pragmatic-baseline` → universal. Filter out low-score rules.
3. **Searches stack-specific rules.** Web search for community-curated rule sets matching detected stack: `"laravel-boost cursor rules"`, `"nextjs app-router rules markdown"`, `"rails cursor rules awesome"`. Surface top candidates by GitHub stars / last-update / license.
4. **Proposes.** Show user a ranked list: `[canonical, score, reason] + [external, source, summary]`. User picks per-item: install / skip / preview-first.
5. **Emits via the agent-agnostic emitter from item #1.**

**Sketch.**

```bash
$ /aikit-setup
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
- Web search dependency: which agent does the search? Probably done by Claude inside the `/aikit-recommend-rules` skill, not a bash script — keeps ai-kit dependency-free.
- Trust model for external rules: ai-kit shouldn't auto-install arbitrary markdown from the internet. Always preview-then-confirm, never silently fetch + emit.
- Caching / pinning: do we vendor external rules into `standards/rules/external/` after first install, or keep them as live fetches? (Lean: vendor — reproducibility, offline-friendly, version pinning.)

**Tasks (rough order).**
- [x] Frontmatter schema on all 8 canonical rules: `universal`, `default_mode`, `weight`, `applies_to.{frameworks,architectures}`, `repo_age_min_years`.
- [x] `bin/lib/recommend-lib.sh` — bash + tiny inline python for JSON parsing. Scores against detect-tooling output + repo age.
- [x] `bin/recommend-rules.sh` CLI with `--json`.
- [x] `workflow/skills/aikit-recommend-rules/SKILL.md` — Phase 1 (canonical scoring) + Phase 2 (web search) + Phase 3 (emit) flow with trust model.
- [x] Vendoring convention documented in the skill (provenance frontmatter, pin-by-SHA, preview-before-write).
- [x] Wired `/aikit-recommend-rules` into `/aikit-setup` as Tier B Branch 12 (2026-05-22); the choice is recorded in the marker via `write-setup-marker.sh --rule-recommendation`.
- [x] First external rule vendored — `standards/rules/external/laravel-php-83.mini.md` from `PatrickJS/awesome-cursorrules` (CC0-1.0), pinned to SHA `4467ad4` (2026-05-22). Validates the Phase 2 → Phase 3 trust flow.
- [ ] **Open:** caching strategy for repeated web searches (no current caching — every invocation re-fetches).

---

## 3. Primitives-uitbreiding (subagents, slash commands, plugin, MCP)

**Status:** **landed** 2026-05-21. PR 0 through PR 3 shipped on master. Triggered by an inventory against the "12 Must-Use Claude Code Features" listicle — gap analysis showed ai-kit was using 4 of the 7 actionable primitives (CLAUDE.md, Rules, Skills, Hooks); this round added the other 4 actionable ones (Subagents, Slash commands, Plugin, MCP). The 3 N/A items (Permissions, Plan Mode, Voice, Rewind) are Claude Code built-ins.

**Direction.** Claude Code voorop, Cursor pariteit waar haalbaar. PR 0 ships an architecture doc + glossary + decision-tree as anti-drift foundation BEFORE adding primitives, so future contributors know which primitive type fits which problem (see `docs/architecture.md`, `docs/glossary.md`, `docs/primitives.md`).

**Landed.**
- [x] **PR 0** — `docs/architecture.md` (three-layer model: source → distribution → host, per-primitive routing table), `docs/glossary.md` (alphabetical terms with explicit aliases), `docs/primitives.md` (decision tree + worked examples + anti-patterns). Skill-count drift fixed (was "16" in `ai-kit-which.sh`, now tense-agnostic).
- [x] **PR 1** — Two subagents (`workflow/agents/aikit-explore`, `workflow/agents/aikit-reviewer`) with the inline-fallback delegation pattern. Five slash commands (`workflow/commands/aikit-{doctor,which,status,no-globals,upgrade}.md`). `install-global.sh` refactored to `install_dir_to` + `install_files_to` (skills + agents + commands). `bootstrap-project.sh` learns `merge_agents` + `merge_commands` with `--no-agents` / `--no-commands` opt-outs.
- [x] **PR 2** — Plugin distribution: `workflow/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`. Users install via `/plugin marketplace add yusufkaracaburun/ai-kit` then `/plugin install ai-kit@ai-kit`. `bin/sync-plugin-version.sh` keeps VERSION / plugin / marketplace / mcp/package.json in lockstep; called from `bin/release.sh` on every tag. Doctor warns on plugin+symlink co-existence. `docs/install-plugin.md` walks through the three install paths and trade-offs.
- [x] **PR 3** — MCP server (`mcp/`): Node + TypeScript, stdio transport, 5 read-only tools (`ai_kit_which`, `ai_kit_skill`, `ai_kit_rule`, `ai_kit_doctor`, `ai_kit_list`). Security: `execFile` not `exec`, zod-validated inputs, 10s timeout, 1 MB output cap, stderr-only logging. CI matrix Node 20 + 22. Reaches Cline / Continue / Zed / Claude Desktop users that the symlink-install and plugin path don't cover.

**Open follow-ups (PR 4 territory — not blocking).**
- [ ] **Hook in the plugin.** v1 plugin doesn't ship the PostToolUse skill-logging hook (path resolution from plugin context is shaky). If we want plugin-only users to get usage stats, bundle a copy of `post-skill-log.sh` inside `workflow/hooks/` and add `hooks/hooks.json`. Opt-in via `AI_KIT_USAGE=1` either way.
- [ ] **Subagent source-of-truth.** PR 1 duplicates the review checklist in both `workflow/skills/aikit-review/SKILL.md` (Cursor inline path) and `workflow/agents/aikit-reviewer/AGENT.md` (Claude Code delegate). Acceptable for v1; v2 should add an emitter (like `bin/emit-rules.sh`) that derives the agent prompt from the skill body. Avoids drift.
- [ ] **Migrate more skills to subagent delegation.** Today only `aikit-review` delegates. Candidates: `aikit-qa`, `aikit-diagnose`, `aikit-improve-codebase-architecture`, `aikit-to-issues` — all do heavy reads that would benefit from isolation. Apply the same `## Run mode` block + inline-fallback pattern.
- [x] **`mental-model.md` refresh.** Landed in PR 4 — now documents 19 skills with the matching table, plus dedicated subagent and slash-command tables linking `architecture.md` / `glossary.md` / `primitives.md`.
- [ ] **MCP server: publish to npm.** Day-one path is "node /path/to/clone/mcp/dist/server.js" after `npm install && npm run build`. `npm install -g @yusufkaracaburun/ai-kit-mcp` becomes available after first publish — no functional blocker, just packaging.
- [ ] **MCP v2 additions.** `ai_kit_recommend_rules` (when cwd arg lands), file-writing tools with consent flow, HTTP transport for remote clients.

---

## What's next

Stub emitters, the first vendored external rule, and the `/aikit-recommend-rules`
→ `/aikit-setup` wiring all shipped 2026-05-22. Remaining, in priority order:

1. **Migration guide** for legacy `.cursor/rules/*.mdc` installs in `docs/troubleshooting.md` (emeq/admin already cleaned manually).
2. **Publish ai-kit-mcp to npm** so users don't need a clone (see section 3 follow-ups).
3. **Web-search caching** for `/aikit-recommend-rules` — every invocation re-fetches today.
