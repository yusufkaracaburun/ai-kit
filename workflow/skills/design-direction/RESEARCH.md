# Research guide

Use the smallest source set that can resolve the design decision. Inspiration
creates possibilities; it does not prove that a direction will work.

## Source hierarchy

1. **Project evidence** — customer language, analytics, support questions,
   brand assets, sales calls, and the actual journey.
2. **Standards and empirical research** — accessibility standards, documented
   usability studies, and design-system guidance.
3. **Live market evidence** — current competitor pages and adjacent products
   serving the same audience or task.
4. **Pattern and inspiration libraries** — useful for references and divergent
   ideas, never the sole rationale for a decision.

For every external source record the URL, access date, useful observation,
confidence, and implication. Note login, paywall, region, or sample limitations.

## Recommended sources

### Standards and evidence

- [W3C WCAG 2.2 contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  — minimum contrast requirements; treat as a constraint, not a style recipe.
- [Material Design 3 color system](https://m3.material.io/styles/color/system/overview)
  and [IBM Carbon color guidance](https://carbondesignsystem.com/elements/color/overview/)
  — semantic roles, states, and systematic palette construction.
- [Baymard checkout usability research](https://baymard.com/research/checkout-usability)
  — evidence for commerce journeys; check whether the finding applies to the
  product and audience before reusing it.
- [Reinecke et al. on visual complexity and first impressions](https://www.eecs.harvard.edu/~kgajos/papers/2013/reinecke13predicting.shtml)
  — empirical framing for rapid aesthetic judgment, with cultural and sample
  context retained.

### Real-product patterns

If `ui-ux-pro-max` or `lazyweb` is already installed in this project, query
them first — they are a live, structured pattern/palette database and a
screenshot reference tool respectively. Fall back to manual browsing below
only for what they don't cover.

- [Refero Styles](https://styles.refero.design/) — AI-readable `DESIGN.md`
  examples with colors, typography, spacing, and components. Use it to name and
  specify a direction, not to outsource the choice. Availability and access may
  change; the optional MCP is not required by this skill.
- [getdesign.md](https://getdesign.md/) — catalog of `DESIGN.md` analyses from
  real live sites (colors, typography, spacing, components, and the reasoning
  behind them). Free to browse; custom per-site analysis is paid. Same caution
  as Refero: use to name and specify, not to outsource the choice.
- [Mobbin](https://mobbin.com/) — current app, web, screen, and user-flow
  patterns. Some depth requires an account or paid plan.
- [Page Flows](https://pageflows.com/) — interaction and user-flow references;
  verify access and plan limits before relying on it.

### Website art direction

- [SiteInspire](https://www.siteinspire.com/) and
  [Land-book](https://land-book.com/) — searchable website and landing-page
  references.
- [Awwwards](https://www.awwwards.com/) — useful for expressive visual and
  motion ideas. Award work may optimize novelty over clarity, performance,
  accessibility, or conversion; borrow selectively.
- [Godly](https://godly.website/) — trend and composition stimulus, subject to
  the same caution as other visual galleries.

On Awwwards and Godly, note motion specifically — easing style, trigger
(hover/scroll/load), and duration — not just the static visuals. For
illustration style specifically, browse [unDraw](https://undraw.co/) or
[Humaaans](https://www.humaaans.com/) to name a spectrum (flat, isometric,
line-art, photographic) rather than defaulting to whichever style is fastest
to generate.

Never copy a whole visual identity or a competitor's distinctive assets. Save
the principle and pattern, not a pixel-for-pixel imitation.

## Research sequence

1. Read project/customer evidence and state the decision.
2. Inspect 5–8 direct competitors at the same page and journey stage.
3. Inspect 2–3 adjacent-category examples for useful patterns the category has
   not exhausted.
4. Check standards and relevant empirical sources.
5. Use 2–3 inspiration libraries to broaden the option space.
6. Cluster repeated category conventions, whitespace opportunities, and trust
   signals. Label each as **keep**, **challenge**, or **test**.
7. Convert findings into project-specific principles before choosing colors.

Capture screenshots only when permitted and useful. Always retain the source
URL and date because gallery contents and live competitors change.

