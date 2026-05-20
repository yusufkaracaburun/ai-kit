# Architecture setup guide (for /setup skill)

Use during **branch 7 — Architecture**. One question at a time. Read this before the branch.

Run detection first (optional but recommended):

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --json
```

Use the `architecture` block in the JSON as your **Finding**.

## Explore (repo layout)

### Frontend signals

| Signal | Likely approach |
| ------ | --------------- |
| `src/features/` or `features/` per domain | Feature folders / FSD-like (`feature-folders`) |
| `app/pages/` + `components/` (Next/Nuxt) | Pages + co-located components (`pages-components`) |
| `resources/js/Pages/` (Inertia) | Laravel-Inertia pages (`laravel-inertia`) |
| `apps/*/src/` + `nx.json` | Nx monorepo app boundary (`nx-monorepo`) |

### Backend signals

| Signal | Likely approach |
| ------ | --------------- |
| `app/Http/Controllers/` only, thin controllers | Laravel default / MVC (`laravel-default`) |
| `app/Actions/` or `app/Services/` | Action/service layer (`action-service`) |
| `src/Domain/` or `Domain/` | Domain-centric / DDD tactical (`domain-centric`) |
| `internal/` + `ports/` | Ports-adapters hint (`ports-adapters`) |
| Nx `libs/` shared packages | Modular monolith (`modular-monolith`) |

Also check for existing `docs/agents/architecture.md` or ADRs that describe structure.

## Recommendation rules

- **Brownfield + clear pattern** → Document detected layout; follow existing — no new methodology push.
- **Ambiguous** → ask one choice: `documented` | `follow-existing` | `skip`.
- **Greenfield + user wants structure** → offer at most 2 options with tradeoffs; suggest ADR for the chosen approach via `grill-with-docs`.
- **Simple CRUD / solo / thin stack** → recommend **skip** (no mandatory `architecture.md`).

## Ask the user

> **Explainer:** `architecture.md` tells agents where FE/BE code lives in *this* repo. It is not a methodology catalog — load-bearing choices still go in ADRs.

Choices map to `.ai-kit-setup.branches.architecture`:

| Choice | Apply |
| ------ | ----- |
| **skip** | No file; `architecture = "skipped"` |
| **follow-existing** | Short doc: "follow detected layout"; minimal bullets; `architecture = "follow-existing"` |
| **documented** | Full `docs/agents/architecture.md` from template; link ADRs; `architecture = "documented"` |

## Apply

1. Copy template from `$AI_KIT_ROOT/context/templates/docs/agents/architecture.md` when not skipping.
2. Fill **Approach**, **Layout**, **Conventions** from detection + user answers — no generic Clean/Hexagonal essays.
3. Cross-cutting: monorepo boundaries, where new features go, pointer to `improve-codebase-architecture` and `grill-with-docs`.

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" --architecture=documented
# or follow-existing | skipped
```

## Verify

If architecture is not skipped:

```bash
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)"
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)" --strict   # FE/BE sections filled
```
