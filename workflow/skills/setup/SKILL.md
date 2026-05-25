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

Then:

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=solo-both|solo-global|project-only|brownfield \
  --tier=minimal \
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

## Tier B branches (optional)

| # | Branch | Default brownfield |
| - | ------ | ------------------ |
| 3 | Docker | use detect `docker.recommendation` |
| 4 | Issue tracker | use detect `issue_tracker.recommendation` |
| 5 | Triage labels | map to existing |
| 6 | Domain docs | skip if no CONTEXT yet |
| 7 | Architecture | skip simple CRUD; else document-existing |
| 8 | Sandcastle | skip brownfield |
| 9 | Agile workflow | informal solo default |
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

### Branch 12 — Rule recommendation (optional refinement)

Bootstrap (Branch 1) emits every `universal: true` canonical rule. For a
brownfield repo on a specific stack, [`/ai:recommend-rules`](../ai:recommend-rules/SKILL.md)
tailors the set — it scores canonical rules against the detected frameworks and
can surface community rule packs from the web.

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
(`standards/external/mcp-servers.json`), and Claude Code hooks
(`standards/external/hooks-patterns.json`) against the detected stack and
project shape. ai-kit never auto-installs — the skill previews each
candidate and lets the user pick per item.

Offer it once. The skill may search the web for upstream install commands, so
never run it silently:

> Optional: `/ai:recommend-tools` scores companion tools, MCP servers, and
> Claude Code hooks against this stack. Wire any in now?
> [1] Refine now    → run `/ai:recommend-tools`, then record `completed`
> [2] Later         → `deferred`
> [3] Keep default  → `skipped`

Default: brownfield with a framework in `detect-tooling` → offer; otherwise
`skipped`. Record the choice in the marker (`--tool-recommendation=...`).

Full setup Done:

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=... --tier=full \
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

Summarise what was configured. Re-run `/ai:setup` to extend Tier A → Tier B later.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" setup start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" setup done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

