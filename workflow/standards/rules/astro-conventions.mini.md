---
name: astro-conventions
description: Astro conventions — static-first islands discipline, content collections, SEO baseline (canonical, sitemap, zero-JS budget)
applies_to:
  frameworks: ["astro"]
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Astro conventions

Astro is static-first: HTML by default, JavaScript by exception. The SEO
advantage the framework was chosen for erodes one `client:load` at a time —
guard the zero-JS budget like a performance budget.

## Islands discipline

- Static by default. A component gets a `client:*` directive only when it
  handles user interaction — never just to render data.
- Cheapest directive that works: `client:visible` (below the fold) over
  `client:idle` over `client:load`. A `client:load` needs a stated reason.
- One interactive widget does not justify a framework runtime. Trivial
  interactivity (menu toggle, accordion) is a plain `<script>` in the
  component, not a React island.

## Content collections

- Markdown/MDX content lives in `src/content/` with a Zod schema in
  `src/content.config.ts`. No untyped glob imports of `.md` files.
- Query via `getCollection()` so frontmatter drift fails at build time,
  not silently in production.

## SEO baseline

- `site` is set in `astro.config.mjs`. Without it there is no canonical
  URL and no sitemap — everything below depends on it.
- Every page renders a unique `<title>` and meta description through the
  shared layout, server-side — never injected client-side.
- Canonical on every page: `new URL(Astro.url.pathname, Astro.site)`.
- `@astrojs/sitemap` integration installed, `robots.txt` points at the
  generated sitemap.
- Images go through `astro:assets` (`<Image>`): dimensions enforced (no
  CLS), modern formats generated at build.
- Pages meant to rank stay prerendered. `output: 'server'` or a per-route
  `prerender = false` needs a named reason (auth, personalisation) — the
  static render *is* the SEO case for Astro.

## Integrations and APIs

- Add integrations with `astro add <name>` (wires config and deps in one
  step), not hand-edited config plus a bare install.
- Verify Astro APIs against current docs (Astro docs MCP or ctx7) before
  coding against them — the framework moves fast and training-data APIs
  are routinely stale.

---

Distilled from docs.astro.build (Build with AI + core guides), 2026-08-23.
