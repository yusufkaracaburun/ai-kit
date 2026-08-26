---
name: recommend-tools
description: Recommend optional companion tools (graphify, caveman, ponytail, llm-wiki) and stack-specific runtime helpers — MCP servers + Claude Code hooks — for the current project. ai-kit writes integration glue, never auto-installs. Use when the user asks "should I add graphify / caveman / ponytail / a self-maintaining wiki", "which MCP servers fit this stack", "any hooks I should turn on", "set up companion tools", "fewer tokens", or after /ai:setup to layer extra capability.
---

Recommend and wire **companion tools** for this project — external AI-productivity tools that sit alongside ai-kit's lifecycle skills. ai-kit configures them; it never vendors or auto-installs them. Same trust model as `recommend-rules`: surface, let the user choose, wire only what they pick.

## What a companion tool is

A third-party tool *or pattern* that improves the AI coding setup but is **not** part of ai-kit's agile lifecycle. ai-kit owns the *integration glue* (a rules block, a hook, a scaffold), never the tool itself. The current catalog lives at `standards/external/companions.json` — that file is the source of truth for which companions exist, their tiers, detection signals, and conflict checks. The table below summarises; see the JSON for fields, glue paths, and conflict rules. Four are known today:

| Companion | Optimizes | Effect | Risk |
| --------- | --------- | ------ | ---- |
| **graphify** | Input — what the AI reads about the code | Knowledge graph; scoped subgraph per query instead of raw grep. Large token cut on multi-file repos. | Low — invisible infra, just better retrieval. |
| **caveman** | Output — how verbosely the AI replies | Compresses responses (drops articles/filler/hedging), technical content intact. ~65% fewer output tokens. | Medium — it is a *communication mode*, opinionated. |
| **ponytail** | Code — how much the AI builds | YAGNI ladder before writing: exists? → in codebase → stdlib → native platform → dependency → one line → minimum. Safety, validation and error handling are never cut. | Medium — it is a *code-generation bias*, opinionated. |
| **llm-wiki** | Memory — knowledge from non-code documents | Self-maintaining wiki; ingests specs/transcripts/research into interlinked pages. The wiki, not the raw files, is the artifact that compounds. | Low — additive scaffold; the agent owns `wiki/`, never touches `raw/`. |
| **context7** | Documentation — live library docs vs. training-data snapshots | MCP server (project-scope) + optional user-scope `~/.claude/rules/context7.md` rule. Cuts API hallucinations on third-party libraries. Universal: any project with deps benefits. | Low — read-only doc lookups, no auto-install of packages. |

They are orthogonal to each other and to ai-kit. Recommend per project, never blanket — except **context7**, which scores `universal: true` in `standards/external/mcp-servers.json` and surfaces for every stack the deterministic recommender runs against (Phase "MCP servers + Claude Code hooks + Claude Code plugins" below).

## When to invoke

- After `/ai:setup`, when the user wants to push the setup further than rules + skills.
- When the user asks "should I add graphify / caveman / ponytail here", "make this cheaper", "fewer tokens".
- On a brownfield repo with many files — graphify earns its keep fastest there.

## Process

### Phase 0 — Inventory (host-state audit)

Before recommending anything new, audit what is already wired on the host. This prevents double-recommending tools the user already runs, and surfaces scope mismatches that would otherwise survive the recommendation pass.

```bash
"$AI_KIT_ROOT"/bin/ai-kit-audit-ecosystem.sh --json
```

Read the `findings` array and apply per verdict:

- **`OWNED`** — already in an ai-kit catalog and present on the host. Do not re-recommend; note "already wired" inline when the user asks about that companion.
- **`KEEP-EXTERNAL`** — present but explicitly out of ai-kit scope. Same treatment as OWNED.
- **`ADOPT`** — present, useful, not in any catalog. File `/ai:followup` with label `catalog-candidate` to queue it for VETTING.md review. Mention to the user that this is a promotion candidate, not a current recommendation.
- **`REBIND`** — scope mismatch (project-scoped where user-scope makes sense) or duplicate marketplace install. Surface the convergence command (`/plugin uninstall X && /plugin install X --scope user`) from `ai-kit-audit-ecosystem.sh --converge` and ask the user to run it before Phase 3 wiring.
- **`REPLACE`** — user-scope skill/agent shadows the ai-kit plugin version. Surface the `rm` command and ask the user before Phase 3.
- **`DROP-STALE`** — references a path that no longer exists. Surface the uninstall command unconditionally.

The audit is read-only; nothing is migrated automatically. The convergence recipe is only printed.

If the user passes `--skip-inventory` to the skill invocation, Phase 0 is skipped (use only when the host has just been audited).

### Phase 1 — Detect

Check what is already present on the machine and in the repo:

```bash
command -v graphify >/dev/null 2>&1 && echo "graphify: CLI present" || echo "graphify: not installed"
[ -d graphify-out ] && echo "graphify: already initialised in this repo" || echo "graphify: not initialised here"
[ -d graphify-out/wiki ] && echo "graphify: --wiki tier present" || echo "graphify: --wiki tier not generated"
{ [ -d "$HOME/.claude/skills/caveman" ] || [ -d .claude/skills/caveman ]; } && echo "caveman: skills present" || echo "caveman: not installed"
claude plugin list 2>/dev/null | grep -qi ponytail && echo "ponytail: installed" || echo "ponytail: not installed"
{ [ -d wiki ] && [ -d raw ]; } && echo "llm-wiki: scaffolded in this repo" || echo "llm-wiki: not scaffolded here"
[ -d docs ] && echo "llm-wiki: conflict-check — existing docs/ found (see Phase 3 llm-wiki branch)" || true
# context7: check BOTH user-scope MCP AND plugin-provided. `claude mcp list` alone misses plugin-provided MCPs that aren't currently connected — adding a user-scope ctx7 in that state causes a "same command/URL" conflict on next /doctor.
{ claude mcp list 2>/dev/null | grep -qi context7 || claude plugin list 2>/dev/null | grep -qi context7; } && echo "context7: already available (user-scope MCP or plugin)" || echo "context7: not available — recommend the plugin path first"
```

Report the lines plainly. Detection drives the recommendation — never claim a tool is wired when it is not. The two graphify lines disambiguate **base tier** (`graphify-out/`) from **wiki tier** (`graphify-out/wiki/`); the wiki tier is an opt-in nudge described in Phase 3.

### Phase 2 — Recommend per project

Judge fit against the actual repo, do not blanket-recommend:

- **graphify** — strong fit when the repo has many files / is brownfield / the user greps a lot. Weak fit for a tiny single-file repo. If the CLI is missing, point the user at the upstream install (one line); a focused web search for the current install command is fine — do not guess it.
- **caveman** — universal (`universal: true`), so `/ai:setup` Branch 2e already auto-prompts it; by the time this skill runs the answer is usually recorded in `branches.universal_companions_prompted`. **Check the marker first and do not re-ask.** Only surface it here when the project has no marker, or the user is explicitly revisiting the decision. It stays **auto-prompted, never silently installed** — the machine-wide blast radius (it changes the agent's output style in *every* repo on the machine) must be stated whenever it is offered. Applier: `bin/apply-caveman.sh`.
- **ponytail** — universal (`universal: true`), same Branch 2e treatment as caveman: check `branches.universal_companions_prompted` first and do not re-ask. Same machine-wide blast radius (it changes how the agent writes code in *every* repo on the machine), so state it whenever it is offered. Applier: `bin/apply-ponytail.sh`. It is **orthogonal to caveman, not an alternative** — caveman compresses prose, ponytail constrains code; upstream endorses running both.
- **llm-wiki** — strong fit when the project accumulates **non-code documents** (PRDs, meeting transcripts, competitor research, PDFs) the user re-reads to find things. Weak fit for a pure code repo — **graphify** already indexes code. Do not recommend graphify and llm-wiki for the *same* need; they cover code vs. documents respectively.

State, for each: present-or-not, fit for *this* repo, and the one-line why.

### Phase 2b — Surface deliberate exclusions

Recommendations have a flip side: tools ai-kit **considered and deliberately does
not adopt**. The audit (`ai-kit-audit-ecosystem.sh`, Phase 0) only emits
`EXCLUDED` / KEEP-EXTERNAL when the tool is *already installed* on the host — so a
fresh project never learns what was rejected. Close that gap here.

Read `standards/external/plugins-excluded.json` and surface every `excluded[]`
entry as a short "considered, not adopted" list — `name` + the one-line gist of
`reason`. Frame it as a deliberate curation boundary, not a backlog: these are
*not* promotion candidates. Keep it to one line each; point the user at the
`alternative` field (direct-install pointer) only if they ask about a specific
entry. This is the complement to the audit's installed-only KEEP-EXTERNAL path.

### Phase 3 — Wire what the user picks

Glue templates live in `$AI_KIT_ROOT/context/templates/companions/`. Wire only the tools the user agreed to.

**graphify:**
1. Append `companions/graphify.md` to the project `AGENTS.md` (agent-agnostic — Cursor + plain-agent reads). Skip if an equivalent block is already there.
2. **Claude Code present (`.claude/` exists at project root).** Auto-loading: Claude Code reads `CLAUDE.md` directly; `AGENTS.md` only fires via explicit reference. To make the "query graph first, don't grep" rule fire reliably, *also* write the graphify block to `CLAUDE.md`. Two paths, in order of preference:
   1. If `graphify` CLI is available, run `graphify claude install` in the project — upstream owns the wording, exact-idempotent on re-run.
   2. Otherwise append `companions/graphify.md` to `CLAUDE.md` directly. Use a fenced marker `<!-- ai-kit:graphify -->` (open + close) around the block so re-runs replace-in-place instead of stacking duplicates. Skip if an equivalent block (heading `## graphify` followed by `graphify query`) is already present.

   Cursor-only projects (no `.claude/`) stop at step 1 — `AGENTS.md` is enough.
3. **No hook to wire.** `/ai:setup` Branch 2d already installed `search-delegation-check.sh` (a `PreToolUse(Bash|Grep|Glob)` hook), and it emits the "run `graphify query` instead of grepping" nudge automatically the moment `graphify-out/graph.json` exists. If the project has no marker (never ran `/ai:setup`), wire it now: `$AI_KIT_ROOT/bin/apply-search-delegation-hook.sh "$(pwd)"`. The applier replaces any older graphify-only nudge instead of stacking a second entry.
4. Copy `companions/graphifyignore` to the project root as `.graphifyignore`. **Skip if the file already exists** — never clobber a project's own ignore list. The starter file excludes `node_modules/`, `vendor/`, build outputs, lockfiles, agent scratch dirs, binary assets, and `graphify-out/` itself, so the first `graphify .` run produces a clean graph instead of indexing generated junk.
5. Tell the user to run `graphify .` (or the upstream's init command) once to build `graphify-out/`, then `graphify update .` after code changes.
6. **Wiki tier (opt-in).** If `graphify-out/` exists but `graphify-out/wiki/` does not, mention the opt-in tier: `graphify . --wiki` generates a Markdown wiki of the graph (AST-only, no LLM cost). Useful when the agent does many symbol-lookup grep'ing — wiki-page browsing is faster than per-query subgraphs for navigation. Decision rule: recommend only when the user explicitly asks for it, the repo is large enough that `query` results scroll past a page, or the recent transcript shows >3 grep/find calls for symbol locations. Otherwise skip — `query`/`path`/`explain` cover the common case. Companion catalog entry: `standards/external/companions.json` → `graphify.tiers.wiki`.

**caveman:**
1. **Check the marker first.** If `branches.universal_companions_prompted` already contains `caveman`, `/ai:setup` Branch 2e handled it — do not re-ask, do not re-run the applier. Report the current state (`bin/apply-caveman.sh --status`) and move on.
2. Otherwise, offer it with the machine-wide caveat stated (see Branch 2e for the prompt wording). On yes: `$AI_KIT_ROOT/bin/apply-caveman.sh`. It adds the marketplace, installs the plugin via the official `claude plugin` CLI, writes caveman's `defaultMode`, and strips the duplicate hooks caveman's own standalone installer leaves behind.
3. Append `companions/caveman.md` to the project `AGENTS.md` — a short note that the mode exists and how to toggle it. ai-kit vendors no caveman source; the plugin comes from its own marketplace.

**ponytail:**
1. **Check the marker first.** If `branches.universal_companions_prompted` already contains `ponytail`, `/ai:setup` Branch 2e handled it — do not re-ask, do not re-run the applier. Report the current state (`bin/apply-ponytail.sh --status`) and move on.
2. Otherwise, offer it with the machine-wide caveat stated (see Branch 2e for the prompt wording). On yes: `$AI_KIT_ROOT/bin/apply-ponytail.sh`. It adds the marketplace, installs the plugin via the official `claude plugin` CLI, and writes ponytail's `defaultMode`. No de-duplication step is needed — ponytail ships no standalone hook installer.
3. Append `companions/ponytail.md` to the project `AGENTS.md` — a short note that the ladder exists, that safety is never cut, and how to toggle it. ai-kit vendors no ponytail source; the plugin comes from its own marketplace.

**llm-wiki:**
1. **Conflict-check first.** If `docs/` exists, surface the conflict warning from `standards/external/companions.json` → `llm-wiki.conflicts[0]` verbatim: *llm-wiki is orthogonal to docs/ — use it for raw-input ingestion (PDFs, transcripts), NOT to migrate existing curated docs. Existing docs/ stays as-is; raw/ is for new untreated source material.* Confirm the user understands the split before scaffolding. The agent must never relocate, rewrite, or "consolidate" files under the existing `docs/` tree into `wiki/`.
2. Skip if `wiki/` already exists. Otherwise scaffold from `companions/llm-wiki/`: copy `wiki-schema.md` → project `wiki/SCHEMA.md`, copy the starter pages (`index.md`, `overview.md`, `glossary.md`, `log.md`) → project `wiki/`, and create an empty `raw/` for source documents.
3. Append a short pointer block to `AGENTS.md`: where the wiki lives, that `wiki/SCHEMA.md` is the operating manual, the three operations — ingest / query / lint — and (if `docs/` existed at scaffold time) the explicit boundary note that `docs/` is for curated material owned by humans, `wiki/` for material derived from `raw/` by the agent.
4. **Wiki disambiguation.** If `graphify-out/wiki/` exists (graphify's `--wiki` tier scaffolded), prepend a "Two wikis present — disambiguation" block to the llm-wiki pointer in `AGENTS.md` naming the two surfaces explicitly: **graphify-wiki** at `graphify-out/wiki/` (AST, code-symbol navigation) vs. **llm-wiki** at `wiki/` (curated, concepts / sources / glossary / overview). When the user says "the wiki" the agent must check both. Skip this block when only one is wired — single-companion installs stay clean. Cross-ref: `standards/external/companions.json` → `graphify.conflicts[]` and `llm-wiki.conflicts[1]`.
5. Tell the user to drop a document in `raw/` and say "ingest" to start. Obsidian is an optional viewer for the wiki — mention it, do not install it.

### Phase 4 — Output contract

End by reporting:

- **Wired:** which tools, which files changed (`AGENTS.md`, `CLAUDE.md` when Claude Code project, `.claude/settings.json`, `.graphifyignore` for graphify when newly written).
- **Needs install:** any recommended tool whose CLI/skills are missing — with the upstream pointer.
- **Deferred:** tools the user said "later" to.
- **Deliberately excluded:** the names surfaced in Phase 2b, one line — so the user sees the curation boundary, not a gap.
- **Next step:** for graphify, the init command to run.

If a file edit or merge failed, say so. Never report a tool wired when its glue is not on disk.

## Extended: MCP servers + Claude Code hooks + Claude Code plugins + Claude Code subagents + self-host PaaS

A separate, deterministic recommender scores five vendored tables under
`standards/external/`:

- `mcp-servers.json` — stack-signal → MCP server
- `hooks-patterns.json` — stack-signal → hook recipe
- `plugins.json` — stack-signal → Claude Code plugin (from the
  marketplaces the user trusts)
- `subagents.json` — stack-signal → Claude Code subagent (Agent tool
  specialists from third-party plugins)
- `paas.json` — `deploy_shape=self-host` → self-host PaaS (v1: Coolify
  only; Dokku / Caprover / Kamal deferred to follow-up issues)

against the same `detect-tooling.sh` output that drives
`/ai:recommend-rules`, so the suggestions are reproducible and never
guessed. The PaaS row uses the new `deploy.shape` field emitted by
`detect-tooling.sh`: `serverless` (vercel.json / netlify.toml / wrangler /
serverless.yml / SAM), `self-host` (Dockerfile + compose, or Coolify
marker like `.coolify/`), `mixed`, or `unknown`. Coolify also emits a
companion MCP recommendation (`mcp-servers.json` → `coolify`) when the
same signals match — second-order: pick the PaaS, then optionally wire
the MCP server.

### When to surface

Add this layer when the user wants more than companion tools:

- "Which MCP servers fit this project?"
- "Any hooks I should turn on?"
- "Which Claude Code plugins should I install for this stack?"
- "Which specialist subagents should I have available?"
- "Where should I self-host this?" (PaaS row fires only when
  `detect-tooling.sh` reports `deploy.shape=self-host` or `mixed`)
- After the companions phase, when the user is willing to spend a few
  more minutes hardening the setup.

### Run the scorer

```bash
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path>           # ranked table
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --json    # machine-readable
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --kind mcp
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --kind hook
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --kind plugin
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --kind subagent
"$AI_KIT_ROOT"/bin/recommend-tools.sh <project-path> --kind paas
```

Output rows: `name`, `score`, `category`, `kind` (`mcp`|`hook`|`plugin`|
`subagent`), `reason`. Higher score = stronger signal. Universal entries
(gitleaks, branch-guard, claude-mem, ask-questions-if-underspecified,
claude-code-guide, etc.) always score 1; framework / file / git-remote
matches push the score up.

### Surface — never wire silently

Present the ranked list grouped by `kind`. For each entry show: `name`,
`category`, `score`, the one-line `reason`, and a **source-count
annotation** per [`standards/promotion-quorum.md`](../../../standards/promotion-quorum.md):

- `(sources: N/M verified)` when at least 2 independent sources document
  the same usage — eligible for default-on recommendation.
- `(sources: 1 — preview only)` for single-source entries — surfaced but
  **never** default-recommended. The skill must not pre-select them; the
  user can still pick them explicitly.

Vendored catalogs under `standards/external/` carry `source_url` +
`pinned_sha` provenance, but the quorum bar is a *surface-layer* check: an
entry can live in the catalog with one source and still be surfaced — only
the default-recommend status is gated.

Worked example output (excerpt):

```
mcp/
  context7    (sources: 2/2 verified)  score=3   universal
    reason: universal — library docs lookups
  obscure-x   (sources: 1 — preview only)  score=1   universal
    reason: gh-stars 12 + one blog post  (not default-recommended)
```

Then ask the user which to wire. Same trust posture as `/ai:recommend-rules`:

- **MCP servers:** never auto-install. Walk the user through their
  preferred install path (`.mcp.json` checked in, `~/.claude.json`
  global, or interactive `claude mcp add`). ai-kit does not vendor MCP
  server code.
- **Hooks:** never write to `.claude/settings.json` without an explicit
  yes per hook. When the user approves a hook, generate a minimal
  recipe matching the entry's `event` + `matcher` and merge into the
  project's `.claude/settings.json` `hooks` block — preserve any
  existing entries.
- **Plugins:** never auto-install. The `install` field on each entry is
  the canonical `/plugin install <name>@<marketplace>` command — show
  it to the user, let them paste it. ai-kit does not vendor plugin
  source. If the marketplace is not yet registered in the user's
  Claude Code, surface that as a separate step.
- **Subagents:** never auto-install. Subagents ship as part of their
  parent plugin (`parent_plugin` field), so the install path is the
  same `/plugin install <name>@<marketplace>` command — show it, let
  the user paste it. Each entry documents the `tools` list the
  subagent gets (Bash / Read / Edit / etc.); surface it inline so the
  user can judge the trust surface before installing the parent
  plugin. ai-kit does not vendor subagent source.
- **PaaS:** never auto-install, never write Docker / compose / server
  config. Surface the entry's `tradeoffs` (interface, topology,
  `vs_alternatives`) + `license` posture verbatim. Point the user at
  `upstream` for installation — they own the VPS and the install.
  After the user picks a PaaS, surface the second-order MCP server
  recommendation from `mcp-servers.json` if it scored alongside (e.g.
  picking Coolify → offer Coolify MCP).
- **No web search.** This phase is fully deterministic from the
  vendored tables. If the user wants MCP servers / hooks / plugins /
  subagents beyond what is vendored, they can extend
  `standards/external/*.json` and re-vendor with provenance (source
  URL, license, pinned SHA).

### Re-vendoring the tables

The two vendored tables under `standards/external/` carry the upstream
SHA pin in `_meta`. Refresh them only with explicit user confirmation —
fetch the new content from the pinned source repo, replace the file,
bump `pinned_sha` + `vendored_at`. Treat them as ai-kit ships them; do
not silently fetch new upstream content during a run.

## Trust model

- **Never vendor the tool itself.** ai-kit does not copy graphify or caveman source into the repo, and does not include MCP server source. They install from their own upstreams; ai-kit writes only the glue. For llm-wiki, ai-kit ships its own schema adapting a public pattern (Karpathy's `llm-wiki.md`) — it vendors no upstream repo. The only things ai-kit vendors are the **signal → recommendation tables** under `standards/external/`, with provenance frontmatter.
- **llm-wiki: `raw/` is the user's, `wiki/` is the agent's.** The agent never edits or deletes anything under `raw/`.
- **Never auto-install** the tool itself — surface the install pointer, the user runs it. The one exception is a `universal: true` companion, which `/ai:setup` **auto-prompts** and, on an explicit yes, installs via the tool's own official CLI (`bin/apply-caveman.sh` → `claude plugin install`). Prompted is not silent: no companion is ever installed without the user saying yes to a prompt that names the blast radius.
- **caveman is never *silent*.** It is auto-prompted (default yes) by `/ai:setup` Branch 2e, never enabled behind the user's back, and the prompt states that activation is machine-wide — it changes the agent's output style in every repo on the machine. `bin/apply-caveman.sh --uninstall` reverses it.
- The search-delegation hook is additive context only — it cannot block a tool call, only suggest.
- **MCP / hook / plugin / subagent recommendations are suggestions, not installs.** The scorer ranks; the user picks per entry; only then is anything written.
