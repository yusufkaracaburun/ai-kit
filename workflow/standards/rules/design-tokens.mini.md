---
name: design-tokens
description: Design tokens generated from one source, with a build-time check that no stylesheet references a token nothing defines — CSS drops the declaration silently
applies_to:
  frameworks: []
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Design tokens

A design token is a contract between whoever decides the value and whoever
spends it. The contract breaks quietly: `var(--brand-clr)` where the token is
called `--brand-color` throws nothing. The browser drops that one declaration,
the element falls back to an inherited or initial value, and the page renders
*nearly* right. No console error, no failed build, no failing test. The design
looks subtly off and nobody can say since when.

Type checkers do not see inside `var()`. Linters flag malformed values, not
missing ones. This needs its own check.

## One generated source

- Tokens come from one source of truth — a design file, a JSON manifest, a
  theme block — and the code-side token file is **generated** from it. Mark
  generated files as generated, in a header, so nobody hand-edits them.
- Regenerate on the build path (a `prebuild` step or equivalent), not on a
  command someone has to remember. A generator you must invoke by hand drifts
  the first busy week.
- Hand-maintaining tokens in two places is the same bug with extra steps: the
  two copies disagree and neither side errors.

## The check that earns its place

Fail the build when a stylesheet uses a token nothing defines:

- Collect defined names from the generated file **and** the locally declared
  ones — a stylesheet legitimately declares its own scoped variables, and a
  check that misses those cries wolf until someone disables it.
- Collect used names from every `var(--…)` reference, including the ones inside
  component files: inline SVG fills and `style` attributes reference tokens too,
  and they are the references most often missed.
- Exit non-zero with the offending names. "Unknown token" plus a list is
  actionable; a boolean is not.

Keep it a static comparison of two sets. It needs no browser and no running
app, so it belongs where it cannot be skipped rather than in a test suite.

## Fallbacks hide the failure

- `var(--x, 12px)` never errors and never will. The fallback makes a missing
  token permanent and invisible — the page uses the wrong value forever, and
  the check above cannot distinguish intent from typo.
- Use a fallback only where the token is genuinely optional. Everywhere else,
  no fallback: you want the check to catch it, not the browser to paper over it.

## Both directions drift

- **Used but undefined** — the silent one above. Build-time check.
- **Defined but unused** — dead tokens accumulating in the theme. Cheaper to
  count than to prevent; a baseline count that may not grow is enough.

The first breaks the page. The second only bloats it. Spend the build-time
check on the first.

## Hard rules

- A generated token file is never hand-edited; fix the source and regenerate.
- No public build without the used-but-undefined check on the build path.
- A missing token is a broken build, not a warning — the whole point is that the
  browser already treats it as a non-event.
- Do not add a fallback to silence the check. That converts a caught bug into a
  permanent wrong value.

## See also

- [`tailwind.mini.md`](./tailwind.mini.md) — the utility-first variant, including
  counting the opposite direction (tokens defined with zero uses).
- [`a11y.mini.md`](./a11y.mini.md) — contrast tokens are the ones whose silent
  fallback does the most damage.
