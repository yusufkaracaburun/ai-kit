---
name: worker-fronts-static-site
description: Static marketing/site assets behind an edge Worker. Mutations and redirects live in the Worker, not in the static generator, and the Worker handler is what you test
applies_to:
  frameworks: ["astro"]
  languages: ["typescript"]
  architectures: ["frontend"]
universal: false
default_mode: always-on
paths: ["wrangler.jsonc", "wrangler.toml", "**/worker/**", "src/pages/api/**", "astro.config.*"]
weight: medium
repo_age_min_years: 0
---

# Worker fronts the static site

A static generator (Astro and kin) builds HTML into an assets directory. A
Cloudflare Worker (or equivalent edge process) sits in front with
`ASSETS` + `run_worker_first`. Forms, lead posts, and legacy redirects are
**Worker concerns**. Putting them in the generator as SSR routes quietly
abandons the static deploy and leaves `astro check` green while every
`POST /api/*` 404s under preview.

## Split of ownership

- **Generator**: pages, islands, assets, sitemap. Output is files. No
  runtime that must handle `POST`.
- **Worker**: `POST /api/*`, honeypot / rate-limit / mail (or D1 write),
  redirect map, then `env.ASSETS.fetch(request)` for everything else.
- One shared redirect table (or equivalent) is what the Worker reads. Do
  not maintain a second copy only the SSG knows about.

## What you test

- Unit-test the Worker handlers (valid body → redirect / 2xx, honeypot
  silent success, validation 4xx, rate-limit 429). Wire that suite into
  the same `check` / CI job as the site build.
- `astro check` + a green build prove HTML, not that a form works. A
  project whose only form coverage is the static build has no form
  coverage.

## Local parity (minimum)

- With static output and a standalone Worker, `astro preview` and a bare
  `astro dev` do **not** run the Worker (with `@astrojs/cloudflare`, dev
  runs in workerd). Either document `wrangler dev` (assets + Worker) as
  the form-smoke path, or add a thin `astro:server:setup` middleware that
  reuses the **same** handler module the Worker imports. A second,
  divergent "dev-only" stub that never sees the real validation is how
  production breaks silently.

## Hard rules

- Mutating public endpoints for a static marketing site live in the
  Worker (or documented edge process), never as the reason to flip the
  whole site to SSR.
- The Worker handler ships with tests in the same change as the form.
- Redirects that the edge applies are skipped from SSG paths (or asserted
  as redirects), so the build does not emit a conflicting page.

## See also

- [`astro-conventions.mini.md`](./astro-conventions.mini.md): static-first
  islands and SEO. This rule is the edge half of that split.
- [`public-surface.mini.md`](./public-surface.mini.md): crawlable HTML
  assertions. Forms are not a crawler concern but share the "assert the
  real path" mindset.
- [`testing-pyramid.mini.md`](./testing-pyramid.mini.md): Worker unit
  tests are the cheap base for form behaviour.
- [`deployment-on-demand.mini.md`](feedback/deployment-on-demand.mini.md):
  deploy still waits for an explicit go.
