---
name: setup
description: Stack-agnostic ai-kit onboarding — one setup-mode question, fast Tier-A path by default, optional full branches for Docker, tracker, domain, architecture, Sandcastle. Claude Code and Cursor. Use when the user wants to install ai-kit in a repo, set up ai-kit, onboard a project to ai-kit, re-run setup to extend Tier A → Tier B, or invokes `/ai:setup`. Re-runs idempotently — the `.ai-kit-setup` marker triggers keep/change/skip per branch instead of overwriting.
---

# Setup (ai-kit)

Configure ai-kit in this repo. **Single entry point.**

## Resolve ai-kit root

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
```

If empty: ask the user or run `bin/ai-kit-root.sh` from the ai-kit clone.

## Grill-me contract

One branch at a time: Explore → Finding → Recommendation → Question → Apply.

If `.ai-kit-setup` exists: **keep / change / skip** per branch.

Guides: [agent-stack-guide.md](./agent-stack-guide.md) · [automation-guide.md](./automation-guide.md) · [docker-guide.md](./docker-guide.md) · [architecture-guide.md](./architecture-guide.md)

Templates: `$AI_KIT_ROOT/context/templates/docs/agents/`

## Before branch 0

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --json
```

Read `monorepo` and `boost` from the JSON:

- `monorepo.detected` → manifests live in subdirs (`monorepo.apps[]`). The
  root scan is partial; handle in Branch 2.
- `boost.detected` → Laravel Boost owns `boost.managed_files[]`. ai-kit never
  patches those (`agents-patch.sh` skips any `<laravel-boost-guidelines>` file);
  see Branch 1.

### Legacy gsd detection

```bash
$AI_KIT_ROOT/bin/ai-kit-migrate-gsd.sh --project "$(pwd)"
```

Always run this. Output is a dry-run listing — exit 0 with `(nothing detected)`
means the user is clean. **If any artifacts are listed**, ai-kit's predecessor
(`get-shit-done` / `gsd`) is co-installed. Its SessionStart hooks surface every
`gsd-*` skill in Claude Code's available-skills list, which silently competes
with `/ai:*` and confuses the agent. Surface the finding to the user verbatim
and offer two paths:

1. **Migrate now** — re-run with `--apply` (and `--project` if any project
   artifacts were listed). The tool prompts "Keep a backup before
   removing? [Y/n]" — default backup lands in
   `~/.cache/ai-kit/migrate-gsd-<ts>/`. Pass `--no-backup` to skip the prompt
   and delete irreversibly, or `--backup` to skip the prompt and always back up.
2. **Keep both** — explicit user choice; warn that `gsd-*` will keep
   appearing in the skill menu and may shadow `/ai:*` autoselection.

Never apply without confirmation — this touches `~/.claude/` which is shared
across every project on the machine.

## Fast path (default)

Ask once: **Fast (Tier A, ~5 min)** or **Full (Tier B)**?

**Tier A — enough to work:**

| # | Branch | Apply |
| - | ------ | ----- |
| 0 | Setup mode | one question (below) |
| 1 | Bootstrap | scripts from mode |
| 2 | Dev environment | `--write` + refine URLs |
| 2b | Lifecycle | one question (below) — default `development` |
| 2c | Universal MCPs | auto-prompt each `universal: true` MCP not yet handled |
| 2d | Search-delegation hook | auto-apply, no question (below) |
| 2e | Universal companions | auto-prompt each `universal: true` companion not yet handled |

Then:

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=solo-both|solo-global|project-only|brownfield \
  --tier=minimal \
  --lifecycle=development|production \
  --universal-mcps-prompted=context7,... \
  --universal-companions-prompted=caveman,... \
  --search-delegation-hook=wired \
  --docker=skipped --tracker=skipped --workflow=skipped \
  --domain-docs=skipped --architecture=skipped --sandcastle=false --context-drift-hook=skipped
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)" --strict --minimal
```

**Tier B — on demand:** branches 3–9 below. Skip any the user does not need.

## Branch 0 — Setup mode (one question)

See [agent-stack-guide.md](./agent-stack-guide.md).

**Choices:** solo-both | solo-global | project-only | brownfield

| Mode | install-global | bootstrap |
| ---- | -------------- | --------- |
| solo-both | yes | `--merge-skills` |
| solo-global | yes | `--no-skills` |
| project-only | no | `--merge-skills` |
| brownfield | usually yes | `--merge-skills` + `--write-agent-stack` if needed |

Default recommendation from detect: `agent_stack.recommendation`.

### Branch 1 — Bootstrap

Run bootstrap per mode (branch 0).

If `boost.detected`: ai-kit writes its sections to `CONTEXT.md` and the root
`CLAUDE.md`, never to a Boost-managed `AGENTS.md`. Tell the user which file
Boost owns (`boost.managed_files[]`) so they know where ai-kit's content landed.

### Branch 2 — Dev environment

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --write
```

Verify official doc URLs live.

If `monorepo.detected`: the root `--write` misses per-app stacks. List the apps
(`monorepo.apps[]`) and ask which to scope dev-environment docs to; note the
others so per-app docs can follow.

### Branch 2b — Lifecycle (one question)

Calibrate every future ai-kit skill to this project's lifecycle phase. The
canonical rule `project-lifecycle` reads `branches.lifecycle` from
`.ai-kit-setup` and flips defaults around schema migrations, backwards-compat,
defensive code, destructive ops, and feature flags. See
[`standards/rules/project-lifecycle.mini.md`](../../../standards/rules/project-lifecycle.mini.md).

> What is this project's current lifecycle phase?
> [1] development — no real users, data is resetable, edit landed migrations freely → `development`
> [2] production  — real users or persistent data; default to additive + backwards-compat → `production`

**Default:** `development` (fresh `/ai:setup` usually runs on greenfield repos).
For brownfield setup-mode the default flips to `production`.

Record via `--lifecycle=development|production`. Re-runs follow the
keep/change/skip pattern — show the current value, ask only if the user picks
`change`. Flip later without re-running setup via [`/ai:phase`](../phase/SKILL.md).

### Branch 2c — Universal MCPs (auto-prompt)

Some MCP servers are valuable on every project regardless of stack — they are
marked `universal: true` in
[`standards/external/mcp-servers.json`](../../../standards/external/mcp-servers.json).
Today that means `context7` (live library docs lookup); future-proof for more.

Tier-A behaviour, one prompt per universal MCP not yet handled by this project:

1. **Read catalog.** Filter `recommendations` for `universal: true`.
2. **Read marker.** Load `.ai-kit-setup` if it exists; collect
   `branches.universal_mcps_prompted` as the already-handled list.
3. **Detect already-installed.** For each candidate, run the detection from
   the catalog entry — typically:
   ```bash
   claude mcp list 2>/dev/null | grep -qi <name> || claude plugin list 2>/dev/null | grep -qi <name>
   ```
4. **Prompt per candidate** that is neither in the prompted-list nor already
   installed:

   > Optional: install `<name>` MCP user-scope (~/.claude.json)?
   > `<value-blurb from catalog>`
   > [1] Yes, install now → run `claude mcp add ...` and record
   > [2] No thanks       → record skipped, never re-prompt

5. **On Yes:** run the install command from the catalog entry. For context7
   today that is `install_paths.fallback_user_scope`:
   ```bash
   claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp
   ```
   Prefer the plugin path (`install_paths.preferred`) when the user already has
   the marketplace wired; the catalog notes the conflict cases.
6. **Record outcome.** Append the candidate name to the prompted-list and pass
   it through `--universal-mcps-prompted=` on the marker write at the end of
   Tier-A. The marker writer stores the union of CSV input and any names
   already in the marker — so re-runs accumulate, never clobber.

**Idempotency.** A second `/ai:setup` reads the prompted-list and skips any
candidate already in it (Yes or No outcome both record the name). Adding a
new `universal: true` entry to `mcp-servers.json` is picked up on the next
run automatically — no skill-body edit needed.

**Trust model.** Prompt-per-tool, never silent install. User-scope means one
install covers all repos on the machine; this branch is intentionally
Tier-A because the universals' value is stack-agnostic.

### Branch 2d — Search-delegation hook (auto-apply)

```bash
$AI_KIT_ROOT/bin/apply-search-delegation-hook.sh "$(pwd)"
```

Wires a `PreToolUse(Bash|Grep|Glob)` hook that fires **only on repo-wide
sweeps** — a Bash `grep`/`rg`/`find`, or a `Grep`/`Glob` with no `path` to
narrow it. A search already scoped to a directory stays silent.

On a wide sweep it points the agent at the cheaper route: `graphify query`
when `graphify-out/graph.json` exists, otherwise a sub-agent (`Explore`,
`ai:explore`, `cavecrew-investigator`) so the raw output lands in the
sub-agent's context instead of the main one.

**Why this one does not ask.** Raw search output is the single biggest source
of context bloat, and [`context-discipline`](../../../standards/rules/context-discipline.mini.md)
already mandates delegation — but a rule is prose an agent skips under
pressure. This hook is ai-kit's own primitive, emits advisory
`additionalContext` only (it can never block a tool call), and its blast
radius stops at the project. Same category as bootstrap and dev-environment:
applied, not negotiated. Record `--search-delegation-hook=wired`.

It supersedes the older graphify-only nudge that `/ai:recommend-tools` used to
merge; the applier **replaces** that entry rather than stacking a second one.

### Branch 2e — Universal companions (auto-prompt)

Some companions are worth having on every project regardless of stack — they
are marked `universal: true` in
[`standards/external/companions.json`](../../../standards/external/companions.json).
Today that means `caveman`; future-proof for more.

Same six steps as Branch 2c, with `branches.universal_companions_prompted` as
the already-handled list:

1. **Read catalog.** Filter `recommendations` for `universal: true`.
2. **Read marker.** Collect `branches.universal_companions_prompted`.
3. **Detect already-installed.** Run the entry's `detection.status` when it has
   one — for caveman: `$AI_KIT_ROOT/bin/apply-caveman.sh --status`.
4. **Prompt per candidate** that is neither in the prompted-list nor already
   installed. For caveman:

   > Optional: install + activate `caveman` (machine-wide)?
   > ~65% fewer output tokens — drops articles, filler, hedging; technical
   > content and code stay intact. Ships the `cavecrew-*` sub-agents, whose
   > compressed returns keep raw search output out of your main context.
   > **This changes the agent's output style in every project on this machine,
   > not just this one.**
   > [1] Yes, install + activate (default) → `bin/apply-caveman.sh`
   > [2] No thanks → record skipped, never re-prompt

5. **On Yes:** run the entry's `install.applier`
   (`$AI_KIT_ROOT/bin/apply-caveman.sh`). It adds the marketplace, installs the
   plugin via the official `claude plugin` CLI, writes caveman's own
   `defaultMode`, and strips the duplicate hooks that caveman's standalone
   installer leaves behind. Idempotent — safe to re-run.
6. **Record outcome.** Append the name to `--universal-companions-prompted=`
   on the Tier-A marker write. Yes and No both record, so a second `/ai:setup`
   never re-asks.

**Trust model.** Prompt-per-tool, never silent install — the machine-wide blast
radius is stated in the prompt itself, because a user who says yes in one repo
is changing every other repo too. ai-kit still vendors nothing: the plugin is
installed from its own marketplace by the official CLI, and ai-kit writes only
the glue.

## Tier B branches (optional)

| # | Branch | Default brownfield |
| - | ------ | ------------------ |
| 3 | Docker | use detect `docker.recommendation` |
| 4 | Issue tracker | use detect `issue_tracker.recommendation` |
| 5 | Triage labels | map to existing |
| 6 | Domain docs | skip if no CONTEXT yet |
| 7 | Architecture | skip simple CRUD; else document-existing |
| 8 | Sandcastle | skip brownfield |
| 9 | Agile workflow | 2-dev default (informal review gate; ≥1 reviewer + PR-per-feature, per ai-kit #52) |
| 10 | Automation recommender | propose-but-defer (brownfield default: skipped) |
| 11 | Context-drift hook | offer if `CONTEXT.md` or `docs/adr/` exist |
| 12 | Rule recommendation | offer if `detect-tooling` finds a framework |
| 13 | Repo templates | offer per-file; default skip per file when one already exists |

### Branch 6 — Domain docs (optional)

`CONTEXT.md` (single context) or `CONTEXT-MAP.md` + per-context `CONTEXT.md`
files (multi-context repos) carry the project's domain language — glossary,
boundaries, invariants. Agents read these before acting so they don't drift to
synonyms.

Bootstrap (Branch 1) already copies `CONTEXT.md.template` to the repo root when
no `CONTEXT.md` exists. This branch is the **fill / extend / skip** decision on
top of that scaffold — independent of the issue tracker.

> Optional: `CONTEXT.md` holds the project's domain glossary, boundaries, and
> invariants. Bootstrap left a template at the root.
> [1] Walk me through filling it (`grill-with-docs`)  → `filled`
> [2] Keep the scaffold for later                     → `scaffolded`
> [3] Skip — no domain language to capture yet        → `skipped`

For monorepos or repos with multiple bounded contexts: offer to write
`CONTEXT-MAP.md` at the root that points at one `CONTEXT.md` per context. See
`context/templates/docs/agents/domain.md` for the layout convention.

Default: brownfield with domain-shaped folders (`app/Domain/`,
`src/domain/`, `lib/<domain>/`) → offer `filled`; greenfield → `scaffolded`;
no domain signal → `skipped`. Record the choice in the marker
(`--domain-docs=scaffolded|filled|skipped`).

### Branch 10 — Automation recommender (propose-but-defer)

Surface, don't run. ai-kit installs noch invokeert de recommender. Stel één keer voor en leg de keuze vast in de marker:

> Optional: a separate plugin (`claude-code-setup`) ships an automation
> recommender that scans this repo and proposes hooks/subagents/skills/MCP
> servers. I won't run it — just record your choice.
> [1] Yes, I'll run it now    → `completed`
> [2] Later, remind me        → `deferred`
> [3] No thanks               → `skipped`

Defaults: brownfield → `skipped`, greenfield → `deferred`. Schrijf de keuze naar `branches.automation_recommender`; roep nooit de externe skill aan. Pattern follows `diagnose` → `/ai:improve-codebase-architecture` handoff.

### Branch 11 — Context-drift hook (optional)

A `PostToolUse(Edit|Write|MultiEdit)` hook that nudges the user to update
`CONTEXT.md` / `docs/adr/` when they edit code those docs name. Offer it only
when the project has a `CONTEXT.md`, `CONTEXT-MAP.md`, or `docs/adr/` — it is a
silent no-op otherwise.

> Optional: a context-drift hook reminds you to keep `CONTEXT.md` and ADRs in
> sync when you change documented code. Deterministic, stack-agnostic, opt-in.
> [1] Yes, wire it    → `wired`
> [2] No thanks       → `skipped`

On `wired`:

```bash
$AI_KIT_ROOT/bin/apply-context-drift-hook.sh "$(pwd)"
```

It copies the hook into `.claude/hooks/` and merges a `PostToolUse` entry into
`.claude/settings.json` — non-destructive and idempotent. Record the choice in
the marker (`--context-drift-hook=wired|skipped`). See [ADR-0005](../../../docs/adr/0005-monorepo-boost-context-drift.md).

### Branch 11b — Rename detector (machine-wide, ask once)

A user-global `SessionStart` hook that detects when `$PWD`'s basename matches
a known project but its registered path is gone — strong signal that the user
ran `mv` on the repo. Emits a one-line nudge to run `/ai:rename-housekeeping
<old> <new>` so stale absolute-path refs in memory files get rewritten.

Machine-wide install (not per-project). Skip the prompt if
`~/.claude/hooks/rename-detector.sh` already exists.

> Optional: a user-global rename-detector hook flags stale memory-file paths
> after you `mv` a repo. One-time install; covers every future project.
> [1] Yes, install globally → `wired`
> [2] No thanks            → `skipped`

On `wired`:

```bash
bash "$AI_KIT_ROOT/bin/install-rename-hook.sh"
```

It copies the hook into `~/.claude/hooks/`, merges a `SessionStart` entry into
`~/.claude/settings.json`, and seeds `~/.claude/known-projects.json`. Idempotent
— a second run prints `rename-detector already wired` and exits.

The skill side (`/ai:rename-housekeeping`) is always available — it ships with
ai-kit. This branch only governs whether the auto-detection hook fires on
every session.

### Branch 12 — Rule recommendation (optional refinement)

Bootstrap (Branch 1) emits every `universal: true` canonical rule, including
the cross-project workflow / style / tool-gotcha rules under
`standards/rules/feedback/` (the canonical feedback-rules layer — see
[`docs/adr/0007-canonical-feedback-rules.md`](../../../docs/adr/0007-canonical-feedback-rules.md)).
For a brownfield repo on a specific stack,
[`/ai:recommend-rules`](../recommend-rules/SKILL.md) tailors the set — it
scores canonical rules against the detected frameworks and can surface
community rule packs from the web.

Offer it once. The skill is interactive (and may search the web), so never run
it silently:

> Optional: `/ai:recommend-rules` scores canonical rules against this stack
> and can surface community rule packs. Refine the rule set now?
> [1] Refine now    → run `/ai:recommend-rules`, then record `completed`
> [2] Later         → `deferred`
> [3] Keep default  → `skipped`

Default: brownfield with a framework in `detect-tooling` → offer; otherwise
`skipped`. Record the choice in the marker (`--rule-recommendation=...`).

### Branch 13 — Repo templates (optional)

Drop-in baseline hygiene files live at `$AI_KIT_ROOT/context/templates/repo/`.
Offer the set; for each file the user picks, ai-kit copies it into the repo —
**per-file consent, default skip when the file already exists.** No new bin
script; this branch is a plain `cp` driven by the skill prompt.

> Optional: ai-kit ships baseline repo hygiene files (`.editorconfig`,
> `.gitattributes`, `CODEOWNERS`, `renovate.json`, `.envrc`). Pull any in?
> [1] All missing ones    → copy every file that does not already exist
> [2] Pick per file       → ask once per file (`keep / copy`)
> [3] Skip                → record `skipped`

| Source | Destination | Note |
| ------ | ----------- | ---- |
| `context/templates/repo/.editorconfig` | `./.editorconfig` | charset + line-ending defaults |
| `context/templates/repo/.gitattributes` | `./.gitattributes` | LF normalisation + binary markers |
| `context/templates/repo/CODEOWNERS` | `./.github/CODEOWNERS` | empty template — user MUST fill in handles before committing |
| `context/templates/repo/renovate.json` | `./renovate.json` | Renovate Bot defaults |
| `context/templates/repo/.envrc` | `./.envrc` | direnv stub |

For each chosen file:

```bash
# Example for .editorconfig — repeat per chosen file.
if [ -e ./.editorconfig ]; then
  echo "keep / overwrite / skip?"   # default: keep
else
  cp "$AI_KIT_ROOT/context/templates/repo/.editorconfig" ./.editorconfig
fi
```

`CODEOWNERS` lands in `.github/CODEOWNERS` — `mkdir -p .github` first. After
copying, flag the file to the user: it ships with placeholder `@your-org/...`
handles and must be edited before commit.

Record the aggregate choice in the marker
(`--repo-templates=all|picked|skipped`). Re-runs are idempotent: any file that
already exists is left alone unless the user explicitly chose `overwrite`.

### Branch 14 — Tool / MCP / hook recommendation (optional refinement)

Sibling to Branch 12 for the tool-class catalogs. `/ai:recommend-tools` scores
companion tools (graphify, caveman, llm-wiki), MCP servers
(`standards/external/mcp-servers.json`), Claude Code hooks
(`standards/external/hooks-patterns.json`), Claude Code plugins +
subagents, and self-host PaaS (`standards/external/paas.json`) against
the detected stack and project shape. ai-kit never auto-installs — the
skill previews each candidate and lets the user pick per item. It also
surfaces the **deliberately-excluded** list (`plugins-excluded.json`) so the
user sees what ai-kit considered and chose not to adopt, not just what it
recommends.

Offer it once. The skill may search the web for upstream install commands, so
never run it silently:

> Optional: `/ai:recommend-tools` scores companion tools, MCP servers,
> Claude Code hooks, and (when `detect-tooling.sh` reports
> `deploy.shape=self-host`) a self-host PaaS recommendation against
> this stack. Wire any in now?
> [1] Refine now    → run `/ai:recommend-tools`, then record `completed`
> [2] Later         → `deferred`
> [3] Keep default  → `skipped`

Default: brownfield with a framework in `detect-tooling` → offer; otherwise
`skipped`. When `deploy.shape=self-host`, prefer `Refine now` even on
greenfield — picking a host shapes downstream config. Record the choice
in the marker (`--tool-recommendation=...`).

Full setup Done:

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=... --tier=full \
  --lifecycle=development|production \
  --universal-mcps-prompted=context7,... \
  --universal-companions-prompted=caveman,... \
  --search-delegation-hook=wired \
  --docker=... --tracker=... --workflow=... \
  --domain-docs=scaffolded|filled|skipped \
  --architecture=... --sandcastle=... \
  --automation-recommender=skipped|deferred|completed \
  --context-drift-hook=wired|skipped \
  --rule-recommendation=completed|deferred|skipped \
  --tool-recommendation=completed|deferred|skipped \
  --repo-templates=all|picked|skipped
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)" --strict
```

## Marker shape

```json
{
  "ai_kit_version": "<VERSION>",
  "completed_at": "<ISO8601>",
  "branches": {
    "bootstrap": true,
    "setup_mode": "solo-both",
    "setup_tier": "minimal",
    "dev_environment": true,
    "lifecycle": "development",
    "universal_mcps_prompted": ["context7"],
    "universal_companions_prompted": ["caveman"],
    "search_delegation_hook": "wired",
    "docker": "skipped",
    "issue_tracker": "skipped",
    "architecture": "skipped",
    "workflow": "skipped",
    "sandcastle": false,
    "automation_recommender": "skipped",
    "context_drift_hook": "skipped",
    "rule_recommendation": "skipped",
    "tool_recommendation": "skipped",
    "repo_templates": "skipped"
  }
}
```

The two `*_prompted` lists accumulate across re-runs (union-merge) — a name in
either list is never re-prompted, whether the answer was yes or no. Adding a
new `universal: true` entry to `mcp-servers.json` or `companions.json` is
picked up automatically on the next `/ai:setup`; no skill-body edit needed.

Summarise what was configured. Re-run `/ai:setup` to extend Tier A → Tier B later.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" setup start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" setup done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

