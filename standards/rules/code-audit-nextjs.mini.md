---
name: code-audit-nextjs
description: Next.js-specific audit heuristics — 7 App-Router checks across the 9 canonical audit dimensions (route-handler typing, server-action revalidation, image/font discipline, implicit dynamic, middleware scope, App-vs-Pages mixing). Loaded when the project depends on `next`.
applies_to:
  frameworks: ["nextjs"]
  languages: ["typescript", "javascript"]
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY Next.js audit heuristics

## When to use

Loaded by `/ai:audit-architecture` when the project depends on `next`. Layers on top of [`code-audit.mini.md`](code-audit.mini.md). Co-loads with [`code-audit-react.mini.md`](code-audit-react.mini.md). **Never introduces a new dimension.**

Out of scope: pre-merge diff review (`/ai:review`), runtime / performance profiling, accessibility (separate audit), security (npm audit / `/ai:review` security-deep-pass), React-shaped smells (owned by [`code-audit-react.mini.md`](code-audit-react.mini.md)), TypeScript-language smells (owned by [`code-audit-typescript.mini.md`](code-audit-typescript.mini.md)).

## Strictness

Default — per-finding severity, no floor. Surfaced in the report header: `**Extensions loaded:** audit-architecture-nextjs`.

## Ownership boundary

This rule fires only on **Next.js-framework** smells. The RSC `'use client'` boundary leak (importing `next/headers`, `next/server`, `server-only`) is owned by [`code-audit-react.mini.md`](code-audit-react.mini.md) R6. Each finding row appears exactly once across `[react]`, `[nextjs]`, and `[typescript]` prefixes.

## The 7 heuristics

### Dimension 1 · Design patterns

**N3 — `<img>` for content imagery where `next/image` would own LCP (🟡)**
A `<img src="…" />` element appears in a `*.{tsx,jsx}` under `app/` or `src/app/` for content (not pixel-perfect icons or data URIs). `next/image` provides automatic lazy-loading, AVIF/WebP negotiation, and intrinsic-size layout-shift prevention. Evidence: grep `<img ` excluding decorative tiny icons. Skip when adjacent comment marks intentional (`// next/image-skip:`).

**N4 — Custom font via `<link>` or `@import` instead of `next/font` (🟡)**
External font loaded via `<link rel="stylesheet" href="https://fonts.googleapis.com/…">` in a layout or via `@import url("https://fonts.…")` in global CSS, while `next/font` is not imported anywhere. `next/font` self-hosts the font + generates a font-face with `size-adjust` to eliminate layout shift. Evidence: grep `<link.*fonts\.googleapis` or `@import.*fonts\.` and confirm absence of `next/font` import.

### Dimension 2 · SOLID

*(N-rules don't cover dimension 2 directly; cross-ref `[react]` R1 / R2 for component-shape findings on Next.js components.)*

### Dimension 3 · DRY

*(Owned by `[react]` R3 for component-level duplication.)*

### Dimension 4 · YAGNI / dead-code

*(Owned by `[react]` R5 for unused exports.)*

### Dimension 5 · Naming + comment-drift

*(Owned by `[react]` R8.)*

### Dimension 6 · Coupling / cohesion

*(Owned by `[react]` R2.)*

### Dimension 7 · Layering / dependency direction

**N6 — Middleware matcher absent or matches all (🟠)**
`middleware.{ts,js}` exists but `export const config = { matcher: … }` is missing, or `matcher` is `/` / `'/(.*)'` (effectively all). Middleware then runs on every static asset, `_next/static/`, `_next/image/`, etc. — perf cost on every request and an enlarged blast radius for any auth/redirect logic. Evidence: parse the file's `config` export. Fix: narrow with `matcher: ['/((?!_next/static|_next/image|favicon.ico).*)']` or an explicit path list.

**N7 — Same route segment in both `app/` and `pages/` (🔴)**
`app/<segment>/page.tsx` and `pages/<segment>.tsx` both exist. Next.js resolves App-Router first; the `pages/` copy becomes silently dead code. Worse, edits to the dead file appear to do nothing — a classic-mode-mistake debugging trap. Evidence: cross-list route paths between the two trees. Fix: delete the `pages/` copy after confirming the App-Router copy carries the live behaviour.

### Dimension 8 · Error handling / failure modes

**N2 — Server action mutates data without revalidation (🟠)**
A function tagged `'use server'` calls a write (`prisma.*.{create,update,delete}`, `db.insert(`, raw `fetch` with `method: 'POST'|'PUT'|'PATCH'|'DELETE'`) but the function body never calls `revalidatePath(`, `revalidateTag(`, or `redirect(`. The mutation succeeds; the UI continues to render the stale cached page until the next full reload. Evidence: grep `'use server'` files → walk each exported async function for the mutation pattern → confirm absence of any revalidation call. Fix: add `revalidatePath('/path')` or `revalidateTag('tag')` or `redirect('/path')` after the mutation.

**N5 — Implicit dynamic rendering (🟠)**
`app/**/page.{tsx,ts}` or `app/**/layout.{tsx,ts}` reads `cookies()`, `headers()`, or `searchParams` without an explicit `export const dynamic = 'force-dynamic' | 'force-static' | 'error'` or `export const revalidate = N`. Next.js will switch the route to dynamic rendering silently — caching decisions become opaque, and a small refactor can flip a route between static and dynamic without code review noticing. Evidence: grep for `cookies()` / `headers()` / destructured `searchParams` in the page or layout → confirm absence of `dynamic` / `revalidate` export. Fix: add the explicit export to make the decision visible.

### Dimension 9 · Type safety / contract clarity

**N1 — Route handler missing typing (🟡)**
`app/**/route.{ts,js}` exports an HTTP method handler (`GET`/`POST`/`PUT`/`DELETE`/`PATCH`) whose `Request` parameter is not typed as `NextRequest` (or `Request` with explicit body-schema validation), or returns a bare `new Response(JSON.stringify(…))` instead of `NextResponse.json(…)` / a typed `Response`. Loses Next.js's typed-helpers for cookies/headers/search-params on the request side and content-type/status-code defaults on the response side. Evidence: parse exported handler signatures and return statements. Fix: `import { NextRequest, NextResponse } from 'next/server'` + annotate.

## Output contract

This rule does not write a report. Findings flow through the `audit-architecture` core merge protocol — the Next.js extension emits `## Per-stack findings — nextjs` blocks dimension-keyed, with `[nextjs]` row prefix added by the core merge.

## Anti-patterns

- Re-flagging `'use client'` files importing `next/headers` — owned by `[react]` R6.
- Promoting `N3` to 🔴 without verifying the image is the LCP element of a critical page.
- Flagging server actions on read-only flows — N2 only fires on the mutation heuristic.
- Treating `matcher: '/'` as wrong without checking whether the project deliberately scoped middleware via a different shape (e.g., per-route `runtime`).

## Final checklist

- All 7 heuristics walked (or skipped with reason)?
- Router shape detected (`app` / `pages` / `both`) — N7 only fires on `both`?
- Server-action mutation walk respected the read-only carve-out?
- De-duplicated by root-cause, not by symptom?
- Ownership boundary respected — no React-shaped or TS-language smells (those belong to their own extensions)?
