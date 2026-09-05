---
name: content-honesty
description: Never fabricate user-facing content — every claim, number, quote and link is real or an openly labelled placeholder
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Content honesty

Invented copy looks finished, so nobody reviews it the way they review a
typed-in number. Wrong prose is a bug with legal weight.

## Hard rules

- **No invented claims.** Security, compliance, performance, funding, scale:
  "SOC 2 compliant", "ISO 27001", "300% faster", "trusted by 10,000 teams",
  "GDPR-proof". If there is no source, there is no claim.
- **No invented people.** Testimonials, quotes, customer names, logos, team
  members, avatars, review counts, star ratings.
- **No invented numbers.** Prices, percentages, uptime, user counts, dates.
  A number in UI copy traces to a real source or it does not ship.
- **No ghost links.** Every `href` resolves to something that exists.
  Footer columns of plausible-but-absent pages are fabrication too.
- **Placeholders are written as placeholders.** `[CUSTOMER QUOTE]`,
  `[PRICE]`, "Coming soon" — never realistic-looking filler that reads as
  final. Lorem ipsum in a shipped view is a defect, not a placeholder.
- **An empty section beats a fabricated one.** If real content is missing,
  cut the section or label it. Do not fill it to make the page look done.
- **Say it in the handoff.** Placeholder copy shipped to show a layout is
  declared at delivery, not left to be found.

## Applies beyond marketing pages

- Seed data and fixtures that reach a demo or staging URL a stakeholder
  will open.
- README and docs: benchmark tables, "used in production by", version
  support matrices.
- Commit messages and PR descriptions claiming tests or checks that were
  not run.
- Error copy inventing a cause ("your session expired") the code cannot know.

## See also

- [`writing-style.mini.md`](writing-style.mini.md) — how the prose reads.
- [`a11y.mini.md`](a11y.mini.md) — placeholder text is never a label.
- `/ai:copywriter` — full copy editor; this rule is the always-on floor.

## Provenance

Adapted from `anti-slop` (miqdadbadjuber/anti-slop, MIT) rules R-36 "No
Fabricated Claims" and R-38 "Real Content or Honest Placeholder". The pack
itself was evaluated and not adopted — see
[`external/plugins-excluded.json`](../external/plugins-excluded.json) — this and
[`responsive-layout.mini.md`](responsive-layout.mini.md) were the parts with no
ai-kit equivalent.
