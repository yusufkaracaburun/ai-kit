# Changelog

## Unreleased

## 3.1.0 — 2026-05-23

**Added**
- **`bin/ai-kit-migrate-gsd.sh`** — detect + remove ai-kit's predecessor
  ("get-shit-done" / `gsd`) from `~/.claude/` and an optional `--project`
  directory. Dry-run by default; `--apply` prompts "Keep a backup? [Y/n]"
  on a tty, or honour `--backup` / `--no-backup` non-interactively. The
  prior co-install kept injecting every `gsd-*` skill via gsd's
  SessionStart hook, so chats routed to `/gsd-*` even after ai-kit was
  installed. Also wired into `/ai:setup` (before branch 0) and
  `ai-kit-doctor.sh` (new `Legacy gsd` section).

**Changed**
- **`bin/install-global.sh`** — the `prefer-plugin` opt-out marker now
  also skips linking `~/.claude/skills/` and `~/.claude/agents/` (was:
  slash commands only). With the plugin route giving `/ai:*` to all
  three primitives, this enables a fully plugin-only Claude Code
  install via a single toggle (`ai-kit-prefer-plugin.sh on`).
- **`tests/bin/run-tests.sh` → `tests/bin/run-all.sh`** (refactor) —
  monolithic 1345-LOC sequential runner split into 9 grouped
  case files under `tests/bin/cases/*.sh` + a shared
  `tests/bin/lib/harness.sh`. Dispatched in parallel by
  `tests/bin/run-all.sh`. Same 374 assertions; wall-time 237s → 67s
  (3.5×). CI workflow + PR template + CONTRIBUTING.md updated to call
  `run-all.sh`.

**Fixed**
- **`docs/install-for-agents.md`** — the prompt now branches step 3
  on host (plugin route gives `/ai:*`; curl-installer gives bare
  names) and includes a step 5 that detects the surface so steps 6–8
  use the right command form. Previously the prompt promised
  `/ai:setup` etc. after a curl install that doesn't deliver them,
  causing "command not found" on legacy installs.
- **`docs/troubleshooting.md`** — added entries for "Chats still
  trigger /gsd-*" and "Slash menu shows mixed /ai:foo and bare /foo".

## 3.0.0 — 2026-05-23

**Breaking**
- **Plugin renamed `ai-kit` → `ai`; every skill / subagent / command lost
  the `aikit-` prefix** (commit `8961fee`).
  - `/aikit-checkpoint` → `/ai:checkpoint` (plugin-namespace form);
    22 skills, 3 subagents, 6 slash commands, eval fixtures + goldens dirs
    all renamed in lockstep; 121 referencing files updated.
  - `workflow/.claude-plugin/plugin.json` `name`: `ai-kit` → `ai`.
  - **Marketplace catalog (`yusufkaracaburun/marketplace`) must be bumped
    in lockstep** — plugin name `ai-kit` → `ai`, `ref` `v2.0.0` → `v3.0.0`,
    description + slash-command list refreshed. The 2.0.0 catalog no longer
    matches what `/plugin install` will pull from this repo.
  - Migration for users on `/plugin install`: re-run after the marketplace
    bump; namespace resolution gives `/ai:foo` automatically. Symlink
    installs (`bootstrap-project.sh`) keep bare `/foo` (colon in filename
    is non-portable).
  - Disambiguation hygiene shipped alongside: `followup` vs `to-issues`
    "Not this skill" pointers in both skills' `SKILL.md`; mental-model
    routing table sharpened.

**Added**
- **`standards/external/VETTING.md`** (#22, roadmap §11) — seven-criteria
  bar for any candidate added to `standards/external/` catalogs:
  storage/data-shape parity, benchmark integrity, marketing-vs-code parity,
  license compatibility (MIT or HTTP/MCP-client-only), category-appropriate
  maturity, data-locality disclosure, provenance pin-by-SHA. Re-audit
  cadence: on every new entry, annually, and on any `/should-i-use`
  finding. Initial audit log retroactively approves existing entries
  (`mcp-servers.json` batch, `hooks-patterns.json` batch, the
  `laravel-php-83.mini.md` vendored rule) and records a `REVISIT` row for
  `claude-mem` (deferred until #19 lands an AI-memory catalog category).
  Surfaced by `/should-i-use` MemPalace 2026-05-23 — verdict on the tool
  was Ignore, but the evaluation finding (three documented false README
  claims) was reusable as the codification trigger.
- **Path-pattern triggers in `bin/hooks/context-drift-check.sh`**
  (#26 Tier 1, roadmap §15) — the PostToolUse drift hook now nudges on
  *path patterns* in addition to the existing CONTEXT.md / ADR
  literal-filename match. Stack-aware defaults (Laravel models /
  migrations / policies / seeders / routes; Rails models / db/migrate;
  Next/Node app + pages/api; Django models / migrations) ship inline;
  project override via `.ai-kit/drift-triggers.json`. Per-category
  reminder template ("seeder (mogelijk persona-drift)", "migration
  (mogelijk stale ref drift)", "route-definitie") replaces the single
  generic message when a path-pattern trigger fires. Closes the gap that
  motivated naschool's bespoke `docs-sync` hook. Tier 2 (full audit
  skill) deferred until skill-vs-companion call lands. Non-blocking,
  silent no-op fallback unchanged.

**Breaking** (continued)
- **Plugin marketplace moved out of the ai-kit repo** (#9, roadmap §3).
  The catalog now lives in its own repo,
  https://github.com/yusufkaracaburun/marketplace, so that one stable
  address can list ai-kit + future plugins under `yusufkaracaburun`.
  - **New install path** (the only supported one going forward):
    ```text
    /plugin marketplace add yusufkaracaburun/marketplace
    /plugin install ai@yusufkaracaburun
    ```
  - **Removed**: `.claude-plugin/marketplace.json` at the ai-kit repo
    root. The legacy install path
    (`/plugin marketplace add yusufkaracaburun/ai-kit` then
    `/plugin install ai-kit@ai-kit`) **no longer works** — Claude Code
    will 404 trying to fetch the marketplace catalog from the ai-kit
    repo. Users on the legacy path must re-run the new install
    commands above. (Plugin data on disk is preserved — they will be
    asked to re-confirm the catalog, not re-install the skills.)
  - `bin/sync-plugin-version.sh` no longer touches a marketplace
    catalog locally; it stamps only
    `workflow/.claude-plugin/plugin.json`. The marketplace catalog
    repo's `.claude-plugin/marketplace.json` must be bumped manually
    after each ai-kit release — `bin/release.sh` now prints the
    copy-paste reminder.
  - `docs/install-plugin.md` updated with the new install / update /
    uninstall flow, including a deprecation note on the legacy path
    and a filesystem-fallback for `marketplace remove`.
  - `docs/architecture.md` "Versioning" section updated: one in-repo
    derived artifact (plugin.json), not two.
  - Tests updated — three marketplace-shape assertions deleted (file
    is gone), one assertion added that the file MUST NOT come back,
    and another that `.claude-plugin/` no longer exists at repo root.

**Added**
- **PostToolUse skill-logging hook bundled in the Claude Code plugin**
  (#8, roadmap §3):
  - `workflow/hooks/post-skill-log.sh` + `workflow/hooks/log-skill.sh` +
    `workflow/hooks/hooks.json` ship with the plugin. The matcher
    (`^Skill$` → `${CLAUDE_PLUGIN_ROOT}/hooks/post-skill-log.sh`)
    resolves via the Claude Code-supplied plugin-root env var, so
    plugin-only users get usage stats without setting `AI_KIT_ROOT`.
  - The hook script now resolves its sibling `log-skill.sh` with a
    dual-location lookup: prefers `$SCRIPT_DIR/log-skill.sh` (plugin
    layout), falls back to `$SCRIPT_DIR/../log-skill.sh` (symlink-source
    layout). One script, both installs.
  - `bin/sync-plugin-hooks.sh` is the new drift-guard:
    `bin/hooks/post-skill-log.sh` + `bin/log-skill.sh` are the
    source-of-truth; `workflow/hooks/` is regenerated from them.
    `sync-plugin-hooks.sh --check` exits 1 on any byte-level drift and
    is run by `bin/release.sh` on every release.
  - Opt-in is unchanged: silent no-op unless `AI_KIT_USAGE=1` is set in
    the env. No network calls — JSONL line per invocation to
    `${XDG_STATE_HOME:-~/.local/state}/ai-kit/usage.jsonl`.
  - Tests: drift round-trip on `sync-plugin-hooks.sh`, plus a "hook
    works from plugin layout" suite that mocks an installed
    `${CLAUDE_PLUGIN_ROOT}` tree and asserts the hook (a) writes a log
    entry with `AI_KIT_USAGE=1`, and (b) no-ops if the sibling
    `log-skill.sh` is missing. 15 new assertions, 299 total pass.
  - `docs/install-plugin.md` updated — the hook is now in the
    "Bundled" list with an explicit "opt-in usage logging" section.
- **`/ai:recommend-rules` Phase 2 web-search cache** (#11, roadmap §2):
  `bin/recommend-rules-cache.sh` is a fingerprint-keyed cache so repeated
  invocations on the same stack skip the live community-rule search.
  - Cache key: sha256 over sorted detected frameworks + frontend/backend
    architecture from `detect-tooling.sh`. Stable per stack regardless of
    repo path.
  - Location: `${XDG_CACHE_HOME:-~/.cache}/ai-kit/recommend-rules/<key>.json`
    — user-level so multiple repos with the same stack share the cache.
  - Default TTL: 7 days. Override with `--ttl N` or `AIKIT_CACHE_TTL_DAYS`.
  - Subcommands: `key`, `read`, `write` (stdin), `path`, `clear`.
  - Flags: `--no-cache` short-circuits both read and write (used by the
    skill's `--refresh` / "re-search" path).
  - Invalid JSON is rejected, never persisted. Atomic writes via tmpfile +
    `mv`.
  - `SKILL.md` Phase 2 now reads the cache before searching and writes
    candidates back after a live search, with a documented JSON shape
    (`stack_fingerprint`, `generated_at`, `queries`, `candidates[]`).
  - 13 regression tests in `tests/bin/run-tests.sh` cover key stability,
    hit/miss, TTL expiry, `--ttl` override, `--no-cache` short-circuit,
    invalid-JSON rejection, and `clear`.
- **`followup` skill + `/ai:followup` slash command** (#16, roadmap §4):
  one-shot defer capture. Takes a one-line lead, drafts a GitHub issue in
  house style (`## Pain` / `## Proposed delivery` / `## Why-not` /
  `## Roadmap pointer`), and appends a numbered paragraph to the last
  `## What's next` section of `docs/roadmap.md` referencing the new issue.
  - **Decisions baked in.** Default label `enhancement` (override via
    `--label`); target section is the last `## What's next` (no topic
    heuristics); local-only mode appends the roadmap entry when `gh` is
    unavailable rather than refusing.
  - **Replaces** the per-project memory file `feedback_followup_default.md`
    with a cross-project primitive that ships via the plugin, so the
    default applies everywhere ai-kit is installed.
  - Skill lives at `workflow/skills/followup/SKILL.md`; command at
    `workflow/commands/ai:followup.md` (`allowed-tools: Bash, Read,
    Edit, Write`). Picked up by `bootstrap-project.sh` and the plugin
    automatically — no enrollment needed.
  - Tests: bootstrap-link assertions for the new skill + command across
    `.claude/` and `.cursor/`; commands count bumped 5 → 6; skills count
    bumped 20 → 21; eval-structure fixture
    `tests/eval/prompts/followup/defer-lead.md` covers the
    expects-list. 303 total pass.
  - Docs: `docs/mental-model.md` lifecycle diagram + the "Which skill,
    when" / "Slash commands" tables; `docs/architecture.md` source-layer
    counts; `docs/install-plugin.md` bundled-list counts;
    `workflow/.claude-plugin/plugin.json` description.
- **Stack → MCP server / Claude Code hook recommendations** (#14, roadmap §5):
  ai-kit can now surface runtime-side recommendations (MCP servers and
  Claude Code hooks) the same way `recommend-rules` surfaces canonical
  rules — deterministic, scored against `bin/detect-tooling.sh` output.
  - **Vendored signal tables.** `standards/external/mcp-servers.json` and
    `standards/external/hooks-patterns.json` are distilled from
    `anthropics/claude-plugins-official @ plugins/claude-code-setup/skills/claude-automation-recommender/references/{mcp-servers,hooks-patterns}.md`,
    pinned to SHA `3449c10cd1f254c2529a4a7e96a094ef118a00a5` under
    Apache-2.0. `_meta` carries the source URL, license, SHA and
    `vendored_at` date for re-vendor audits.
  - **Scorer.** `bin/recommend-tools.sh <project> [--json] [--kind mcp|hook|all]`
    + `bin/lib/recommend-tools-lib.sh`. Scores each entry against detected
    `frameworks`, `architecture.{frontend,backend}.detected`,
    `issue_tracker.remote`, and file presence (e.g. `pint.json`,
    `playwright.config.ts`, `.github/workflows`). Universal hooks
    (env / lockfile protection, notification alerts) score 1 by default.
  - **Skill integration.** `workflow/skills/recommend-tools/SKILL.md`
    gains an "Extended: MCP servers + Claude Code hooks" section that
    invokes the scorer, surfaces the ranked list grouped by kind, and
    documents the trust model: never auto-install an MCP server, never
    write to `.claude/settings.json` without per-hook approval, never
    fetch new upstream content silently.
  - **Why not adopt the upstream skill.** `/should-i-use` verdict (#14):
    adopt-as-pattern, not install — the audience is end-users without
    automations, ai-kit already runs the codebase-analysis phase and the
    companion-tools phase, and two recommenders on one repo dilute the
    narrative. The mapping tables are the reusable artifact.
  - Tests: 11 new assertions in `tests/bin/run-tests.sh` covering Laravel
    fixture matching (context7 + laravel-pint + block-env-edits), JSON
    output shape (integer score, kind ∈ {mcp,hook}, sorted desc),
    `--kind` filtering for both kinds, empty-stack fallback (only
    universal hooks surface), and `--kind bogus` rejection. 314 total
    pass.

**Removed**
- **ai-kit scoped to Claude Code + Cursor — MCP server and non-CC/Cursor
  emitters deleted** (ADR-0006, roadmap §4):
  - Deleted `mcp/` entirely — the Node + TypeScript MCP server, its five
    tools, tests, and the `mcp.yml` / `mcp-publish.yml` CI workflows. The
    `@yusufkaracaburun/ai-kit-mcp` npm package has been removed from npm.
  - Deleted `bin/lib/emitters/{aider,cline,cody,continue}.sh` — the four
    non-CC/Cursor rule emitters. `bin/emit-rules.sh` now dispatches to
    `cursor`, `claude-code`, and `generic` (the always-on rule index) only;
    `detect_agents()` detects only Cursor and Claude Code.
  - Deleted `bin/ai-kit-mcp` and its `install-global.sh` symlink step.
    `sync-plugin-version.sh` / `release.sh` no longer touch `mcp/package.json`.
  - Kept: the `generic` emitter (the rule index, not a host), and
    user-project MCP detection (`detect-tooling.sh`, `bootstrap --with-mcp`)
    — a Cursor project may still run its own MCP servers.
  - Rationale: ai-kit is developed and used only on Claude Code and Cursor;
    the multi-host surface cost CI, an npm package, and doc/test weight for
    hosts nobody here runs. See [ADR-0006](docs/adr/0006-scope-claude-code-cursor-only.md).

**Feat**
- **Stub rule emitters finished — aider, cline, continue, cody**
  (`bin/lib/emitters/`, roadmap item #1):
  - `bin/emit-rules.sh` previously printed `skip:<agent>` for these four
    agents. Each now has a real emitter that writes per-rule Markdown to the
    agent's conventional rules directory: `.aider/rules/`, `.clinerules/`,
    `.continue/rules/`, `.sourcegraph/cody/`.
  - A legacy single-file `.clinerules` cannot also be a directory, so the
    Cline emitter skips it (with a reason) rather than clobbering it.
  - All six emitters (cursor, claude-code, generic + the four new ones) are
    covered by `tests/bin/run-tests.sh`.
- **First external rule vendored** (`standards/rules/external/`, roadmap item #2):
  - `standards/rules/external/laravel-php-83.mini.md` — vendored from
    `PatrickJS/awesome-cursorrules` (CC0-1.0), pinned to commit
    `4467ad4`. Validates the `/ai:recommend-rules` Phase 2 → Phase 3
    vendoring + trust flow end-to-end on a real source.
  - New `standards/rules/external/README.md` documents the provenance
    frontmatter schema (`source_url`, `source_license`, `pinned_sha`,
    `vendored_at`) and the pin-by-SHA trust model.
- **`/ai:recommend-rules` wired into `/ai:setup`** (roadmap item #3):
  - New Tier B Branch 12 — "Rule recommendation". Offered when
    `detect-tooling` finds a framework; surfaces `/ai:recommend-rules`
    as an optional refinement, never run silently.
  - `bin/write-setup-marker.sh` learns `--rule-recommendation=completed|deferred|skipped`;
    the choice round-trips in the `.ai-kit-setup` marker.
- **Migration guide for pre-2.0 installs** (`docs/troubleshooting.md`, roadmap #10):
  - New "Migrating from a pre-2.0 install" section — step-by-step cleanup of
    legacy Cursor `.mdc` shims now that rules are emitted by the
    agent-agnostic emitter. Replaces the stale claim that ai-kit "no longer
    generates Cursor rules".
  - Fixed the Re-emit hint in all six rule emitters — they referenced a
    non-existent `--update` flag; `emit-rules.sh` is already idempotent.
- **MCP server published to npm** (`mcp/`, `.github/workflows/mcp-publish.yml`,
  roadmap #4):
  - `@yusufkaracaburun/ai-kit-mcp` is on npm — `npm install -g
    @yusufkaracaburun/ai-kit-mcp` instead of clone + build.
  - `package.json` hardened: `publishConfig.access=public`, `prepublishOnly`
    (clean + build + test), repository object with `directory`.
  - New `mcp-publish.yml` workflow publishes on every `v*` tag push via npm
    OIDC trusted publishing — no long-lived token, automatic provenance.
    A guard step fails the run if the package version != the tag.
- **`bin/emit-agents.sh` — subagent prompt single-sourced from the skill**
  (roadmap #12):
  - A subagent's `AGENT.md` and its companion `SKILL.md` shared the review
    checklist and output-format spec by hand-copy — a drift hazard. The new
    emitter regenerates a marked region of `AGENT.md` verbatim from named
    `SKILL.md` sections.
  - `reviewer/AGENT.md` now pulls `Security deep pass` + `Output
    format` from `review/SKILL.md`. CI runs `emit-agents.sh --check`
    and fails on drift.
- **Four more skills migrated to subagent delegation** (`workflow/skills/`,
  `workflow/agents/`, roadmap #3):
  - Each of `qa`, `diagnose`, `to-issues`, and
    `improve-codebase-architecture` gained a `## Run mode` block —
    Claude Code delegates to a subagent; other hosts fall back to the
    inline process, which stays the single source of truth.
  - New paired subagent `qa-runner` runs the full QA pass (Playwright
    / CLI smoke + deep tests) so large browser and console output stays out
    of the main thread. Its `AGENT.md` single-sources `Tiers` + `Output`
    from `qa/SKILL.md` via `emit-agents.sh`.
  - `diagnose`, `to-issues`, and
    `improve-codebase-architecture` delegate their codebase walk to
    the existing `explore` subagent — the last swapped off the
    generic `Explore`. No bespoke subagent each: they only do codebase
    reads, already `explore`'s job.

## 2.0.0 — 2026-05-22

**Breaking**
- **Every skill is now prefixed ``** (`workflow/skills/`, ADR-0004):
  - All 20 skills renamed — `setup → setup`, `review → review`,
    `tdd → tdd`, and so on through every skill. Skill directories,
    `name:` frontmatter, eval fixtures, goldens, the test suite, docs, and
    both plugin manifests moved in lockstep.
  - Rationale: bare generic names (`setup`, `review`, `ship`, `qa`,
    `resume`) collide with other plugins, the user's own skills, and Claude
    built-ins — `review` already clashes with a built-in. The prefix makes
    each skill's origin obvious and matches the already-prefixed slash
    commands (`doctor`, …) and subagents (`explore`, …).
  - **Action required:** invoke skills by their new names (`/ai:setup`,
    `/ai:review`, …). Old names no longer resolve — re-pull and reload
    skills. `bin/*.sh` script names and `standards/rules/` are unchanged.
  - See [ADR-0004](docs/adr/0004-skill-prefix.md). Major version
    bump to 2.0.0.

**Feat**
- **`recommend-tools` skill — wire companion tools without vendoring them**
  (`workflow/skills/recommend-tools/SKILL.md`,
  `context/templates/companions/`):
  - New 20th skill. Detects optional companions on the machine and in
    the repo — **graphify** (codebase knowledge graph, optimises what
    the AI reads), **caveman** (token-compressed responses, optimises
    how the AI replies), and **llm-wiki** (a self-maintaining knowledge
    base for non-code documents) — and wires whichever the user picks.
    Same trust model as `recommend-rules`: surface, let the user choose,
    never auto-install.
  - ai-kit owns only the *integration glue*, never the tool source. Glue
    templates land in `context/templates/companions/`: a `graphify`
    `AGENTS.md` rules block, a Claude Code `PreToolUse` hook that nudges
    `graphify query` over raw grep, a `caveman` opt-in note, and an
    `llm-wiki/` scaffold (wiki schema + starter pages) adapting Andrej
    Karpathy's `llm-wiki.md` pattern. caveman is never enabled by
    default — it is a communication mode.
  - `/ai:setup` surfaces `/ai:recommend-tools` as an optional follow-up
    (propose-but-defer; setup never runs it).
  - README gains a "Companion tools" section. Skill count 19 → 20 across
    README, `docs/architecture.md`, `docs/glossary.md`,
    `docs/mental-model.md`, `docs/install-plugin.md`, both plugin
    manifests, and the test suite.
- **Brownfield monorepo + Laravel Boost support** (`bin/lib/detect-lib.sh`,
  `bin/detect-tooling.sh`, `bin/lib/agents-patch.sh`, ADR-0005):
  - `detect_monorepo()` — generic, non-Nx monorepo detection: a depth-1
    scan for `composer.json` / `package.json` / `go.mod` / `pyproject.toml`
    / `Cargo.toml`. `detect-tooling.sh --json` gains `monorepo: { detected,
    apps[] }`. Fixes `/ai:setup` detecting "no stack" in repos whose
    manifests live in `backend/`, `admin/`, … subdirs.
  - `detect_boost()` — reports `boost: { detected, managed_files[] }`.
    `agents-patch.sh` now refuses to patch any `AGENTS.md` carrying the
    `<laravel-boost-guidelines>` marker, so ai-kit and Boost stop fighting
    over a regenerated file.
  - New `context-drift` hook (`bin/hooks/context-drift-check.sh`) — a
    `PostToolUse(Edit|Write|MultiEdit)` hook that nudges you to update
    `CONTEXT.md` / `docs/adr/` when you edit code those docs name.
    Stack-agnostic, deterministic, opt-in. `bin/apply-context-drift-hook.sh`
    wires it into a target project non-destructively and idempotently.
    Hook count 1 → 2.
  - `.gitignore` now excludes `.agents/`, `.claude/skills/`, and
    `skills-lock.json` — artifacts a companion tool's own installer
    drops into this clone. ai-kit recommends companion tools; it does not
    commit their installed copies.

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
- **Claude Code subagents — `explore` + `reviewer`** (new
  `workflow/agents/`):
  - `explore` is a read-only codebase exploration subagent. Tools:
    Read, Grep, Glob, Bash. Bounded output (≤300 lines), structured return
    (Summary / Findings / Files inspected / Confidence). Spawn from any
    skill that needs cross-file sweeps without polluting main context.
  - `reviewer` is a pre-merge code review subagent. Same tool set.
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
    `/ai:doctor`, `/ai:which`, `/ai:status`, `/ai:no-globals`,
    `/ai:upgrade`. Each runs the underlying script via `!`-prefix
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
