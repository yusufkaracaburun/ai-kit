---
name: public-surface
description: Public, crawlable HTML — server-side meta and schema, a sitemap that tracks real routes, and assertions on rendered output rather than framework props
applies_to:
  frameworks: []
  languages: []
  architectures: ["frontend", "backend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Public surface

Any route a crawler can reach without logging in is a public surface: marketing
pages, generated per-entity pages, legal pages, `sitemap.xml`, `robots.txt`,
`llms.txt`. Its failure mode is silence — nothing throws, nothing 500s, the
page looks right in a browser, and the crawler gets an empty shell. Guard it
with assertions, not with inspection.

Applies to any stack that serves public HTML — static generators and
server-rendered apps alike. Skip it for API-only services and auth-gated
internal tools.

## Build metadata server-side

- One shared builder produces `<title>`, meta description, canonical, OG tags
  and JSON-LD. Not per-page duplication, not client-side injection — a crawler
  that runs no JavaScript must receive the finished tags.
- Canonical is derived from the current URL, never hand-written per page.
- Non-indexable pages (confirmations, thank-you, previews) carry `noindex`
  **and** stay out of the sitemap. One signal without the other reads as a
  contradiction in Search Console.

## Sitemap tracks real routes

- Generate it from the same source the router uses. A hand-maintained list
  drifts the first time someone adds a route.
- An entity that is not publicly reachable is excluded from the sitemap **and**
  returns 404. Assert both in one test — they drift apart independently.
- Legal and policy pages carry a real `dateModified`. A stale date on a
  document you actually changed is worse than no date.

## robots.txt is environment-aware

- Non-production serves `Disallow: /` and **no** sitemap reference. A staging
  host that leaks into an index competes with production for its own terms.
- Block admin and API prefixes explicitly.
- If you take a position on AI training, state it in a directive rather than
  a blog post. Whatever you choose, assert it — this is the block most likely
  to be silently reverted by a copy-paste from a tutorial.

## Assert rendered HTML, not framework props

The trap in every hydration stack (Inertia, Next, Nuxt, Remix, SSR-mode Astro):
a test that inspects the page object, props, or component tree passes whether or
not the server actually rendered HTML. It asserts your intent, not the crawler's
input.

- At least one test per public route type fetches the response and asserts
  against the **raw body**: the title, the meta description, the JSON-LD.
- Structured data must match visible content. Assert the parity directly —
  build the visible list and the structured list from the response and compare
  them. Schema that promises what the page does not show is a manual action.
- Know your framework's SSR failure behaviour. Most fall back to client-side
  rendering silently. That default is right for users and wrong for crawlers,
  so the fallback needs its own alarm — a listener, a log, a metric.

## Deploy verification reaches the rendered page

- A health endpoint returning 200 says the process is up. It says nothing about
  whether the renderer came back. Those are different failures with the same
  green check.
- The post-deploy check fetches a real public URL and greps for content that
  only exists after rendering. If the check exists but only runs locally, it is
  not a deploy check — wire it into the deploy path.

## Hard rules

- A new public route ships with its sitemap entry and one rendered-HTML
  assertion, in the same change.
- No public surface goes live without a non-production `Disallow: /` guard.
- A green test suite is not evidence that crawlers see the page. Only a
  raw-body assertion is.

## See also

- [`testing-pyramid.mini.md`](./testing-pyramid.mini.md) — where these
  integration-level assertions belong in the mix.
- [`astro-conventions.mini.md`](./astro-conventions.mini.md) — the static-first
  variant of the same concerns.
