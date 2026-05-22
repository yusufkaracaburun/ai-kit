---
name: aikit-setup
description: Stack-agnostic ai-kit onboarding — one setup-mode question, fast Tier-A path by default, optional full branches for Docker, tracker, domain, architecture, Sandcastle. Claude Code and Cursor.
disable-model-invocation: true
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
  --architecture=skipped --sandcastle=false
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

### Branch 2 — Dev environment

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --write
```

Verify official doc URLs live.

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

### Branch 10 — Automation recommender (propose-but-defer)

Surface, don't run. ai-kit installs noch invokeert de recommender. Stel één keer voor en leg de keuze vast in de marker:

> Optional: a separate plugin (`claude-code-setup`) ships an automation
> recommender that scans this repo and proposes hooks/subagents/skills/MCP
> servers. I won't run it — just record your choice.
> [1] Yes, I'll run it now    → `completed`
> [2] Later, remind me        → `deferred`
> [3] No thanks               → `skipped`

Defaults: brownfield → `skipped`, greenfield → `deferred`. Schrijf de keuze naar `branches.automation_recommender`; roep nooit de externe skill aan. Pattern follows `aikit-diagnose` → `/aikit-improve-codebase-architecture` handoff.

Full setup Done:

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=... --tier=full \
  --docker=... --tracker=... --workflow=... \
  --architecture=... --sandcastle=... \
  --automation-recommender=skipped|deferred|completed
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
    "automation_recommender": "skipped"
  }
}
```

Summarise what was configured. Re-run `/aikit-setup` to extend Tier A → Tier B later.

As an optional follow-up, mention `/aikit-recommend-tools` — it wires companion tools
(graphify, caveman) for projects that want to push the AI setup further. Surface
it once; do not run it.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `aikit-retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-setup start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-setup done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

