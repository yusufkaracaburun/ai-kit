---
name: audit-architecture-nextjs
description: Next.js-specific architecture audit — 7 App-Router heuristics across the 9 audit dimensions (route-handler typing, server-action revalidation, image/font discipline, implicit dynamic, middleware scope, App-vs-Pages mixing). Default strictness. Use when `/ai:audit-architecture` runs against a Next.js project (auto-loaded by the extension loader alongside the React extension).
extends: audit-architecture
applies_to:
  frameworks: ["nextjs"]
  languages: []
strictness: default
---

# Audit Architecture — Next.js extension

Per-stack tuning for [`audit-architecture`](../audit-architecture/SKILL.md). Adds 7 Next.js-specific heuristics under the canonical 9 dimensions from [`code-audit.mini.md`](../../../standards/rules/code-audit.mini.md). **Never introduces a new dimension.**

Auto-loaded by `bin/audit-extension-loader.sh` when the project package.json declares `next` (framework key `nextjs` from `bin/detect-tooling.sh`). Loads alongside the React extension; ownership boundary below. Skip with `AI_KIT_AUDIT_NO_EXTEND=1`.

## Ownership boundary with the React + TypeScript extensions

This extension owns **Next.js-framework** smells: route-handler shape, server-action revalidation, framework-idiom violations (`next/image`, `next/font`), implicit dynamic rendering, middleware matcher scope, App-vs-Pages router mixing, typed `metadata`.

The [`audit-architecture-react`](../audit-architecture-react/SKILL.md) extension owns **React-shaped** smells including the RSC `'use client'` boundary leak (R6). The Next.js extension does NOT re-flag client-imports-server-only — that row is owned by `[react]`.

The [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) extension owns **language-level** TypeScript smells.

Each finding row appears exactly once across `[react]`, `[nextjs]`, and `[typescript]` prefixes — when in doubt, prefer the most-specific extension.

## Heuristics

7 heuristics. Stable ID prefix `N<N>`.

| ID | Dim | Severity | Heuristic |
|---|---|---|---|
| N1 | 9 | 🟡 | Route handler `app/**/route.{ts,js}` missing `NextRequest`/`NextResponse` typing or untyped `Response` return |
| N2 | 8 | 🟠 | Server action mutates data but never calls `revalidatePath` / `revalidateTag` / `redirect` |
| N3 | 1 | 🟡 | `<img>` used for content imagery where `next/image` would own LCP / lazy-load |
| N4 | 1 | 🟡 | Custom font via `<link rel="stylesheet">` or `@import` instead of `next/font` |
| N5 | 8 | 🟠 | Route uses `cookies()` / `headers()` / `searchParams` without explicit `export const dynamic` or `revalidate` — implicit dynamic, cache surprises |
| N6 | 7 | 🟠 | Middleware `matcher` absent or `/` (matches all) — runs on every static asset; perf + security blast radius |
| N7 | 7 | 🔴 | Same route segment exists in both `app/` and `pages/` — Next resolves App-Router first, `pages/` route silently dead |

## Process

When invoked after the core walk:

1. **Run tools.** Call `bash "$AI_KIT_ROOT/bin/audit-nextjs-helpers.sh" run_tools <project-path>` to ingest `next lint` JSON output when available. Gated by `command -v` and `next` in `node_modules/.bin/`. Cached under `$TMPDIR/ai-kit-audit-nextjs-<ts>/`.
2. **Detect router shape.** Determine App-Router (`app/` or `src/app/`), Pages-Router (`pages/` or `src/pages/`), or both. Most heuristics target App-Router; N7 specifically requires both.
3. **Walk the 7 heuristics.**
   - **N1:** `find {app,src/app} -name 'route.{ts,js}'` → check each `export async function {GET,POST,PUT,DELETE,PATCH}` for typed `Request: NextRequest` parameter and `NextResponse` / typed `Response` return.
   - **N2:** Grep files containing `'use server'` directive → for each exported async function, look for at least one of `revalidatePath(`, `revalidateTag(`, `redirect(`. Mutation heuristic: the function calls `await db.`, `prisma.*.{create,update,delete}`, `fetch(...{method:'POST'|'PUT'|'PATCH'|'DELETE'})`.
   - **N3:** Grep `<img ` in `*.{tsx,jsx}` under `app/` or `src/app/`. Skip when adjacent comment marks it intentional (e.g. `// next/image-skip:`).
   - **N4:** Grep `<link rel="stylesheet" href="https://fonts.` or `@import url("https://fonts.` and confirm absence of `next/font` import.
   - **N5:** For each `app/**/page.{tsx,ts}` and `app/**/layout.{tsx,ts}`, check whether it (or any imported server module it uses) calls `cookies()`, `headers()`, or reads `searchParams`. If yes, confirm an `export const dynamic = …` or `export const revalidate = …` exists in the same file. Default is implicit dynamic and silently bypasses caching.
   - **N6:** If `middleware.{ts,js}` exists, parse `export const config = { matcher: … }`. Missing matcher OR `matcher: '/'` OR `matcher: '/(.*)'` → flag.
   - **N7:** Compare route-segment paths between `app/` and `pages/`. Same final segment in both → flag the `pages/` copy as silently dead.
4. **Apply severity per the rule.** Default strictness — no floor. Per-finding severity stands.
5. **Emit dimension-keyed markdown** per the contract:

```markdown
## Per-stack findings — nextjs

### Dimension 8 · Error handling / failure modes
- app/actions/update-profile.ts:14 · 🟠 · N2 Server action mutates `prisma.user.update` but never revalidates — stale data after submit · `'use server'\n…await prisma.user.update(…)` with no `revalidatePath('/profile')` · add `revalidatePath('/profile')` or `redirect('/profile')` after the mutation

### Dimension 7 · Layering / dependency direction
- middleware.ts:12 · 🟠 · N6 Middleware matcher absent — runs on every request including static assets · `export const config = {}` · narrow with `matcher: ['/((?!_next/static|_next/image|favicon.ico).*)']`
```

6. **Hand markdown back to the core skill.** Do NOT write the report.

## Helper-script

[`bin/audit-nextjs-helpers.sh`](../../../bin/audit-nextjs-helpers.sh) (companion):

- `run_tools <project-path>` — runs `next lint --format=json` when `next` is on PATH inside `node_modules/.bin/`. Gated. Emits a one-line `Tools ingested:` header on stdout. Caches per-tool raw output to `$TMPDIR/ai-kit-audit-nextjs-<ts>/`.
- `detect_router <project-path>` — emits `app`, `pages`, `both`, or `none`. Surfaced for the report header (`**Router detected:** app`).

Format tools (Prettier) and security scanners (`npm audit`) are out of scope.

## Anti-patterns

- Re-flagging `'use client'` files importing `next/headers` — owned by `[react]` R6.
- Promoting `N3` (`<img>` vs `next/image`) to 🔴 — content imagery is a 🟡 perf finding, not correctness. Only escalate when the file is the LCP image of a marketing-critical page (judgment call; document in the row).
- Flagging Server-Actions-without-revalidation on read-only flows — N2 fires only on the mutation heuristic.
- Asserting `matcher: '/'` is wrong without checking whether the project deliberately scoped middleware to a sub-path via a different config shape.

## Related

- [`audit-architecture`](../audit-architecture/SKILL.md) — core stack-agnostic skill.
- [`audit-architecture-react`](../audit-architecture-react/SKILL.md) — React-shaped smells incl. RSC boundary.
- [`audit-architecture-typescript`](../audit-architecture-typescript/SKILL.md) — TypeScript-language smells.
- [`code-audit-nextjs.mini.md`](../../../standards/rules/code-audit-nextjs.mini.md) — 7 heuristics with evidence patterns.
- [`standards/contracts/audit-architecture-extension.contract.md`](../../../standards/contracts/audit-architecture-extension.contract.md) — extension contract.
