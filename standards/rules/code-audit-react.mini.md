---
name: code-audit-react
description: React-specific audit heuristics — 9 React 19 checks across the 9 canonical audit dimensions, including the RSC server/client boundary and React-19 server-action typing. Loaded when the project depends on react / next / @remix-run.
applies_to:
  frameworks: ["react", "nextjs", "remix"]
  languages: ["typescript", "javascript"]
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY React audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when the project depends on React (raw, Next.js, or Remix). Layers on top of [`code-audit.mini.md`](code-audit.mini.md). Never introduces a new dimension.

Out of scope: pre-merge diff review (`/ai:review`), runtime / performance profiling, accessibility (separate audit), security (npm audit / `/ai:review` security-deep-pass), TypeScript-language smells (owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md)).

## Strictness

Default — per-finding severity, no floor. Surfaced in the report header: `**Extensions loaded:** audit-architecture-react`.

## Ownership boundary

This rule fires only on **React-shaped** smells. Language-level TS smells (`any` past boundaries, `as` casts past edges, generic variance) are owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md). The shared fixture `tests/fixtures/audit-react-ts-overlap/` is the contract-test boundary — each finding row appears exactly once across `[react]` and `[typescript]` prefixes.

## The 9 heuristics

### Dimension 1 · Design patterns

**R4 — `useEffect`-empty-deps async-on-mount where a data-router loader should own (🟡)**
A component does `useEffect(() => { fetchX(); }, [])` to load page-scoped data, in a project that has a router with loader support (Next.js app-router `loader`, Remix `loader`, TanStack-Router `loader`). The data belongs in the loader, not in a component effect. Evidence: grep `useEffect.*\[\]` paired with `fetch(`/`api.`/`axios.` inside the effect body.

### Dimension 2 · SOLID

**R1 — God-component > 300 LOC (🟠)**
`*.tsx`/`*.jsx` component > 300 LOC. Smell: one component owns fetch + state + render + sub-views. Split into container + presentational. Evidence: `wc -l`.

### Dimension 3 · DRY (knowledge-duplication)

**R3 — Same fetch + state-machine pattern duplicated > 2x (🟡)**
The same `useState(loading) + useState(error) + useState(data) + useEffect(fetch)` quartet appears in ≥3 components. Extract a `useFetch<T>` / `useQuery<T>` hook (or adopt a library if not already present). Evidence: AST-pattern grep across components.

### Dimension 4 · YAGNI / dead-code

**R5 — Unused exported component (🟡)**
Component file `export`s a component (default or named) that has no callsite outside its own module. Evidence: `grep -r '<ComponentName' src/` + lazy-route maps.

### Dimension 5 · Naming + comment-drift

**R8 — Mechanism-named components (🟡)**
`*Container`, `*Wrapper`, `*Provider2`, `*HOC`, `*Component` suffix in a codebase where the same concept has a domain name elsewhere. Evidence: grep component file names against the project's `CONTEXT.md` glossary.

### Dimension 6 · Coupling / cohesion

**R2 — Props-bloat > 8 props on a component (🟠)**
A component interface declares > 8 props (excluding `children`). Likely candidates: missing composition seam, or a god-component masquerading as a leaf. Evidence: count interface members / function parameter destructuring.

### Dimension 7 · Layering / dependency direction

**R6 — RSC boundary leak — `'use client'` file importing server-only module (🔴)**
A file with a top-of-file `'use client'` directive `import`s from one of: `server-only`, `next/headers`, `next/server`, `fs`, `node:*`, or anything matching a configured server-only allowlist. Build will fail or — worse — silently bundle a server symbol into client output. Evidence: walk `'use client'` files and grep their imports.

**R9 — Cross-feature reach-through import (🔴)**
A module under a feature root (`src/features/A/**`, `src/modules/A/**` — whichever convention the project uses) imports a **sibling feature's internals** rather than its public entry: `../B/hooks/useThing`, `@/features/B/components/Inner`. Every such import welds two features together; the pair can no longer be moved, deleted, or owned separately, and the "features" stop being boundaries. Evidence: resolve every relative/aliased import to a feature root, flag any that crosses into a sibling and does not land on that sibling's `index.ts` / declared public surface. Fix: export the symbol from the sibling's public entry, or hoist the shared piece into `shared/`. Enforce mechanically with ESLint `import/no-restricted-paths` zones (already available via `eslint-plugin-import` — no new dependency) or `eslint-plugin-boundaries`.

Skip when the project has no feature-root convention — flag the absence once, do not invent one (mirrors the core walk's dimension-7 rule).

### Dimension 8 · Error handling / failure modes

*(R-rules don't currently cover dimension 8 — error-handling on the React surface is project-shape-dependent. Cross-ref the core walk's findings; do not add a placeholder.)*

### Dimension 9 · Type safety / contract clarity

**R7 — Missing typing on `<form action={...}>` server actions (React 19) (🟠)**
A JSX `<form action={fn}>` where `fn` is `Function` / not annotated, or annotated as `(formData: FormData) => Promise<void>` without a typed return-value contract. React 19's `useActionState` / form-action APIs benefit from typed payload + return. Evidence: walk JSX `<form action={…}>` and resolve the bound function's signature.

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the React extension emits `## Per-stack findings — react` blocks dimension-keyed, with `[react]` row prefix added by the core merge.

## Anti-patterns

- Flagging "no Redux/Zustand" on a project that chose `useReducer` deliberately (check `docs/adr/`).
- Promoting `R8` to 🔴 — it's readability, not correctness.
- Re-reporting findings the core already wrote.

## Final checklist

- All 9 heuristics walked (or skipped with reason)?
- RSC boundary: every `'use client'` file's imports checked against the server-only allowlist?
- React 19 specifics surfaced (R7 server-action typing) where applicable?
- De-duplicated by root-cause, not by symptom?
- Ownership boundary respected — no TS-language smells (those belong to `code-audit-typescript.mini.md`)?
