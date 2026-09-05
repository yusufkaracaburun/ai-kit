---
name: responsive-layout
description: Mobile layout that reflows instead of shrinking — breakpoints from content, no horizontal overflow, grids that collapse, fixed bars that reserve their space
applies_to:
  frameworks: ["react", "vue", "angular", "nextjs", "nuxt", "svelte", "remix", "astro", "laravel", "rails", "django"]
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Responsive layout

A mobile layout is a different layout, not the desktop one scaled down. The
failures below are invisible in a desktop preview and obvious the moment a
phone opens the page — which is why they ship.

## Breakpoints

- **Mobile-first, always.** Base styles are the narrow case; breakpoints add
  as the viewport grows. Writing desktop first and overriding downward means
  every narrow screen runs the longest cascade.
- **Breakpoints come from the content**, not from a device list. Add one where
  *this* layout breaks, not at "iPhone width". Device-derived breakpoints go
  stale with every hardware generation.

## Sizing

- **Type and spacing get a mobile scale.** Desktop section padding on a
  360px screen leaves a sliver of content between two walls of whitespace.
- **No fixed px type in fluid containers.** Relative units, so user text
  settings and container width both apply.
- **`100vh` is a trap on mobile** — it excludes the browser chrome that
  appears and disappears on scroll, so the section jumps. Use `100dvh`
  (or `svh`/`lvh` deliberately) and say which you meant.

## Grids and stacking

- **Multi-column grids collapse.** Every grid states what it does at the
  narrow end; columns that stay side by side collide or overflow.
- **No fixed-width grid tracks.** `minmax()`, `fr`, `auto-fit` — a track
  sized in px cannot shrink with its parent.
- **Grid children need `min-width: 0`** (flex children too). Without it a
  long string or a table forces the track wider than the container, and the
  overflow surfaces at the page level.

## Overflow — the one that actually ships

- **Zero horizontal page scroll at the narrowest target.** This is a check,
  not an aspiration: the offender is off-screen in the desktop preview.
  Usual suspects: tables, `<pre>` blocks, images without `max-width: 100%`,
  long unbroken strings (URLs, hashes, IDs).
- **Contain the wide thing, do not shrink the page.** A wide table gets its
  own `overflow-x: auto` scroll container or a reflow layout — the *page*
  body never scrolls sideways.
- **`overflow: hidden` is not a fix.** Clipping hides content and controls
  instead of fitting them. Clip only where cropping is the intent (a
  thumbnail); everywhere else, let it reflow.
- **Check it at the narrowest supported width** — `/ai:qa` covers this in
  its smoke pass; walk it by hand on new layouts.

## Fixed and sticky chrome

- **A fixed bar reserves its own height.** Bottom nav or sticky footer
  without scroll padding covers the last list item, the submit button, the
  thing the user came for.
- **Honour safe-area insets** (`env(safe-area-inset-*)`) on devices with a
  notch or home indicator.
- **Sticky chrome stays compact.** Every fixed pixel is content lost on a
  small viewport; a tall sticky header letterboxes the page.
- **Navigation reflows into a mobile pattern.** A desktop link row kept as a
  row wraps, crowds or spills. Collapse it — and label the trigger, a bare
  hamburger assumes knowledge the user may not have.

## See also

- [`a11y.mini.md`](a11y.mini.md) — tap targets, hover alternatives, focus.
- [`tailwind.mini.md`](tailwind.mini.md) — utility syntax for the same rules.

## Provenance

Layout failure modes adapted from `anti-slop`'s `antislop-layoutmobile` skill
(miqdadbadjuber/anti-slop, MIT). The pack itself was evaluated and not
adopted — see [`external/plugins-excluded.json`](../external/plugins-excluded.json);
this and [`content-honesty.mini.md`](content-honesty.mini.md) were the parts
with no ai-kit equivalent. The `dvh` and `min-width: 0` mechanisms are
ai-kit's own additions.
