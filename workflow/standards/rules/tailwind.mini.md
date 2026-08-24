---
name: tailwind
description: Tailwind CSS conventions — utility-first, design tokens via config, no arbitrary values without reason
applies_to:
  frameworks: ["tailwindcss", "tailwind"]
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Tailwind CSS conventions

Tailwind is a design-system primitive, not a CSS scratchpad. The discipline:
configuration is the source of truth, utilities are how you compose it,
custom CSS is the escape hatch you barely touch.

## Tokens in config, not literals

- Colors, spacing, fonts, breakpoints, radii — defined in
  `tailwind.config.{ts,js}` `theme.extend`. Never `text-[#1a73e8]` or
  `p-[17px]` in markup.
- Arbitrary values (`w-[123px]`) signal a missing token. Add the token to
  config; don't bake one-offs into JSX.
- Tokens reference brand semantics (`bg-primary`, `text-muted-foreground`),
  not raw scale positions (`bg-blue-500`) — unless the brand really is
  "Tailwind blue 500".

## Enforce it — a rule nobody counts drifts

The rules above are greppable. Measure them instead of trusting review: add a
**ratchet** — a script that counts violations, compares against a committed
baseline, and fails when the number *rises*. The ceiling only ever falls.

```bash
# raw palette classes that should be semantic tokens (extend the colour list)
grep -rhoE '\b(text|bg|border|ring)-(slate|gray|zinc|red|amber|emerald|blue|rose)-[0-9]{2,3}\b' src \
  --include='*.tsx' | wc -l
```

- Commit today's count as the baseline. Legacy stays, new drift is blocked —
  no big-bang migration needed to start enforcing.
- Wire it into the project's `validate` chain **and** the pre-commit hook
  **and** CI. Two out of three makes it advisory.
- Same shape for the siblings worth counting: arbitrary values, `style={{}}`
  occurrences, tokens defined in `@theme` with zero uses in markup.
- Don't lean on the Tailwind linter for this. It flags `text-[#fff]` and misses
  `text-emerald-600` — and the valid-but-untokenised class is the drift that
  actually accumulates.

## Component patterns

- Repeated utility strings ⇒ extract a component, not an
  `@apply`-rule. `@apply` belongs in the legacy escape hatch, not the
  default authoring style.
- Variant logic lives in `class-variance-authority` (`cva`), `tv()`
  (tailwind-variants), or a `clsx`/`twMerge` helper — never long
  string-concatenation in JSX.
- shadcn/ui components are the baseline for primitive UI. Customise via
  the `tailwind.config` theme + cva variants, not by editing the
  generated component every time.

## Conditional classes

- Use `cn()` (a `clsx` + `tailwind-merge` helper) to dedupe conflicts
  (`cn('p-4', condition && 'p-2')` → `p-2` wins).
- Boolean toggles, not ternary strings:

  ```tsx
  cn(
    'rounded-md text-sm',
    intent === 'danger' && 'bg-destructive text-destructive-foreground',
    disabled && 'opacity-50 pointer-events-none',
  )
  ```

## Responsive + state

- Mobile-first. `text-sm md:text-base lg:text-lg` — never the inverse.
- State variants in deterministic order: `hover:` → `focus-visible:` →
  `active:` → `disabled:` → `aria-*:` → `data-*:`. Consistency makes
  diffs readable.
- `focus-visible:` (keyboard focus), not `focus:` (mouse focus too) for
  visible-on-tab outlines.

## What not to do

- Don't ship arbitrary `style={{}}` overrides next to Tailwind classes —
  pick one system per component.
- Don't put utility strings into `@layer components` to avoid repetition —
  componentise instead.
- Don't reach for `!important` (`!`) — `tailwind-merge` solves nearly
  every conflict declaratively.
- Don't put `dark:` variants on every utility — define dark-mode tokens in
  config and consume the semantic name.

## See also

- [`a11y.mini.md`](./a11y.mini.md) — `focus-visible` + contrast tokens.
- shadcn/ui: https://ui.shadcn.com — primitive components built this way.
- Tailwind config docs: https://tailwindcss.com/docs/theme
