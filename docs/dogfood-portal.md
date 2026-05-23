# Dogfood log

Real repos `ai-kit` has been validated against. Each entry captures detection output, the choices that were made, and any surprises. These are not test fixtures — they're a record of what the kit does on actual code.

## Index

- [Portal (Nx monorepo)](#portal--nx-monorepo)
- [Laravel + Inertia app](#laravel--inertia-app)
- [Vite + React app](#vite--react-app)

---

## Portal — Nx monorepo

Validated against an Nx workspace with `apps/` + `libs/`, npm, existing `.cursor/playwright/.cursor/rules/*.mdc` (nested), and two MCP configs (`.cursor/mcp.json`, `.vscode/mcp.json`).

### Recommended choices

| Step | Detection | Choice |
| ---- | --------- | ------ |
| Tier | — | **A (fast)** unless team needs full docs |
| Setup mode | MCP + 11 nested playwright rules | **brownfield** |
| Bootstrap | greenfield ai-kit files | `--merge-skills` + `install-global` |
| Dev env | npm + nx | `--write`, verify nx.dev URL |
| Tier B | optional later | docker, tracker, domain, architecture, workflow |

### Detection snapshot

```
Setup mode: brownfield (needs agent-stack doc: true)
Custom rules: .cursor/playwright/.cursor/rules/*.mdc (11)
MCP: .cursor/mcp.json, .vscode/mcp.json
Architecture: nx-monorepo + libs/
```

### Tier A commands

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
$AI_KIT_ROOT/bin/detect-tooling.sh . --write-agent-stack
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .
$AI_KIT_ROOT/bin/detect-tooling.sh . --write
# refine dev-environment.md URLs
$AI_KIT_ROOT/bin/write-setup-marker.sh . --setup-mode=brownfield --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

### Surprises

- Nested `.cursor/rules` (under `playwright/`) is supported but not commonly documented. Detection picks it up via the recursive scan in `detect-lib.sh`.
- Two MCP files coexist (Cursor + VS Code) because the team uses both editors. ai-kit lists both and modifies neither.

Extend to Tier B later with `/ai:setup` Full path.

---

## Laravel + Inertia app

Validated against a Laravel 11 app with Inertia + Vue 3 + Tailwind, Composer + pnpm, `.cursor/rules/{inertia,laravel,tailwind}.mdc`, and a single `.cursor/mcp.json`.

### Recommended choices

| Step | Detection | Choice |
| ---- | --------- | ------ |
| Tier | — | **A (fast)**; Tier B for architecture later |
| Setup mode | 3 custom rules + MCP + 1 custom skill | **brownfield** |
| Bootstrap | greenfield ai-kit files | `--merge-skills` |
| Dev env | composer + pnpm + Vite, Laravel 11 | `--write`, Laravel docs auto-suffixed `/11.x` |
| Tier B | recommended | architecture (for `app/Domain/` layout), workflow |

### Detection snapshot

```
Setup mode: brownfield (needs agent-stack doc: true)
Custom rules: .cursor/rules/inertia.mdc, .cursor/rules/laravel.mdc, .cursor/rules/tailwind.mdc
Custom skills: .cursor/skills/my-team-skill
MCP: .cursor/mcp.json
Architecture: laravel-inertia / laravel-default (recommend: document-existing)
Laravel version: 11 (from composer.lock)
```

### Tier A commands

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
$AI_KIT_ROOT/bin/detect-tooling.sh . --write-agent-stack
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .
$AI_KIT_ROOT/bin/detect-tooling.sh . --write   # Laravel 11 docs URL filled
$AI_KIT_ROOT/bin/write-setup-marker.sh . --setup-mode=brownfield --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

### Surprises

- `composer.lock` parsing in `detect-tooling.sh` correctly extracts the major version and auto-suffixes the Laravel docs URL with `/11.x`. Works for any Laravel ≥6.
- The custom `my-team-skill` was preserved by `--merge-skills`; an early test with `--link-all` would have wiped it. See [ADR-0001](adr/0001-setup-modes.md) consequence section.

---

## Vite + React app

Validated against a single-page Vite + React + TypeScript app, no monorepo, no existing AI tooling, pnpm.

### Recommended choices

| Step | Detection | Choice |
| ---- | --------- | ------ |
| Tier | — | **A (fast)** — no Tier B branches needed |
| Setup mode | no rules, no MCP, no custom skills | **solo-both** |
| Bootstrap | greenfield | `--merge-skills` (default) |
| Dev env | pnpm + vite | `--write`, vitejs.dev URL |
| Tier B | not needed for a solo project | — |

### Detection snapshot

```
Setup mode: solo-both (needs agent-stack doc: false)
Frameworks: react
Package manager: pnpm
Architecture: feature-folders (recommend: keep)
MCP: -
```

### Tier A commands

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .
$AI_KIT_ROOT/bin/detect-tooling.sh . --write
$AI_KIT_ROOT/bin/write-setup-marker.sh . --setup-mode=solo-both --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped \
  --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

### Surprises

- None. Greenfield + Vite + React is the cleanest case; ai-kit finishes Tier A in under 5 minutes including the user reading and confirming the dev-environment URLs.
- `architecture` defaults to `feature-folders` recommendation; ai-kit skips writing `architecture.md` unless the user opts in.
