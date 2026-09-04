---
name: audit-architecture-react
description: React-specific architecture audit — 9 React 19 heuristics across the 9 audit dimensions, including the RSC server/client boundary, cross-feature import direction and React-19-specific server-action typing. Default strictness (per-finding severity, no floor). Use when `/ai:audit-architecture` runs against a React, Next.js, or Remix project (auto-loaded by the extension loader).
extends: audit-architecture
applies_to:
  frameworks: ["react", "nextjs", "remix"]
  languages: []
strictness: default
---

# Audit Architecture — React extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). Adds 9 React-specific heuristics under the canonical 9 dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). **Never introduces a new dimension.**

Auto-loaded by `bin/audit-extension-loader.sh` when the project package.json declares `react`, `next`, or `@remix-run/*`. Skip with `AI_KIT_AUDIT_NO_EXTEND=1`.

## Ownership boundary with the TypeScript extension

This extension owns **React-shaped** smells: prop-bloat, component-size, hook usage, RSC boundary leaks, server-action typing, mechanism-named components.

The [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) extension owns **language-level** TypeScript smells: `any` past module boundaries, `as` casts past edges, generic-component variance, etc.

Non-overlap enforced by the shared fixture `tests/fixtures/audit-react-ts-overlap/` and the contract-test under #79. Each finding row appears exactly once across `[react]` and `[typescript]` prefixes.

## Heuristics

9 heuristics encoded in [`standards/rules/code-audit-react.mini.md`](../../../standards/rules/code-audit-react.mini.md). Stable ID prefix `R<N>`.

| ID | Dim | Severity | Heuristic |
|---|---|---|---|
| R1 | 2 | 🟠 | God-component > 300 LOC |
| R2 | 6 | 🟠 | Props-bloat > 8 props on a component |
| R3 | 3 | 🟡 | Same fetch + state-machine pattern duplicated > 2x — extract custom hook |
| R4 | 1 | 🟡 | `useEffect`-empty-deps async-on-mount where a data-router loader should own |
| R5 | 4 | 🟡 | Unused exported component (no callsite outside module) |
| R6 | 7 | 🔴 | RSC boundary leak — `'use client'` file importing server-only module |
| R7 | 9 | 🟠 | Missing typing on `<form action={...}>` server actions (React 19) |
| R8 | 5 | 🟡 | Mechanism-named components (`*Container`, `*Wrapper`, `*Provider2`) where a domain name exists |
| R9 | 7 | 🔴 | Cross-feature reach-through import (sibling feature's internals) |

## Process

When invoked after the core walk:

1. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-react-helpers.sh" run_tools <project-path>` to ingest ESLint + `tsc --noEmit` output. Both gated by `command -v` (and presence of `eslint` / `tsc` in the project's `node_modules/.bin/`). Cached under `$TMPDIR/ai-kit-audit-react-<ts>/`.
2. **Walk the 9 heuristics.** R1/R2/R8 are file-shape / interface-shape — grep + LOC math. R3/R4/R5 require call-site analysis. R6 needs the RSC boundary: identify files with a leading `'use client'` directive and check their imports against a server-only allowlist (`server-only`, `next/headers`, `next/server`, `fs`, `node:*`). R7 walks JSX `<form action={…}>` attributes and checks the bound function's type annotation. R9 needs a feature root (`src/features/`, `src/modules/` with ≥2 sub-directories) — resolve each import to its feature and flag sibling-internal targets; with no feature root, R9 does not fire.
3. **Apply severity per the rule.** Default strictness — no floor. Per-finding severity stands.
4. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — react

### Dimension 7 · Layering / dependency direction
- app/profile/page.tsx:3 · 🔴 · R6 RSC boundary leak — `'use client'` file imports `next/headers` · `import { cookies } from 'next/headers'` after `'use client'` · move data-fetch into a server component and pass via props

### Dimension 2 · SOLID
- src/pages/Dashboard.tsx:1 · 🟠 · R1 God-component 412 LOC · 6 unrelated jobs (fetch + state machine + render + form + layout + modal) · split into a container + 3 presentational components
```

5. **Hand markdown back to the core skill.** Do NOT write the report.

## Helper-script

[`bin/audit-react-helpers.sh`](../../../bin/audit-react-helpers.sh):

- `run_tools <project-path>` — runs ESLint with `react-hooks/*` + `react/no-array-index-key` + `react/jsx-no-bind` rules in JSON format; runs `tsc --noEmit` when `tsconfig.json` is present. Both gated. Emits a one-line `Tools ingested:` header on stdout. Caches per-tool raw output to `$TMPDIR/ai-kit-audit-react-<ts>/`.
- `detect_rsc <project-path>` — emits `yes` if any file under `app/` or `src/app/` declares `'use client'`; emits `no` otherwise. Surfaced for the report header (`**RSC detected:** yes/no`).

Format tools (Prettier) and security scanners (npm audit) are out of scope.

## Anti-patterns

- Re-flagging dimensions the core already handled.
- Flagging "no Redux/Zustand" in a project that has chosen `useReducer` deliberately (read `docs/adr/`).
- Promoting `R8` (mechanism-named components) to 🔴 — it's a 🟡 readability finding, not correctness.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill.
- [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) — TypeScript-language smells (separate ownership).
- [`code-audit-react.mini.md`](../../../standards/rules/code-audit-react.mini.md) — 9 heuristics with evidence patterns.
- [`bin/audit-react-helpers.sh`](../../../bin/audit-react-helpers.sh) — ESLint + tsc gates.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract.
