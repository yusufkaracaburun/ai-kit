---
name: ui-states
description: Every interactive or async UI element ships its full state set — hover, active, loading, empty, error — not just the happy path
applies_to:
  frameworks: []
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# UI states

A component built to only its happy path looks done in the demo and breaks
the moment real data, a slow network, or an empty result shows up. The gap is
invisible in review because the missing state simply isn't there to see.

## Hard rules

- **Loading is a distinct state**, not a frozen happy-path view. An async
  action shows the user something is in progress.
- **Empty is designed, not blank.** A list, table, or search result with zero
  items gets a composed view (what this is, how to add the first one) — never
  an empty container that reads as a bug.
- **Errors are inline and specific.** Say what failed and, where possible,
  what to do next. Never a native `alert()`/`confirm()`, and never a silently
  swallowed failure — see [`error-handling.mini.md`](./error-handling.mini.md)
  for the underlying fail-fast/never-swallow rule this is the UI surface of.
- **No dead links or buttons.** A control pointing at nothing is either wired
  up or visibly disabled — never a live-looking element with no effect.
- **Current location is indicated in navigation.** The active nav item, tab,
  or breadcrumb reflects where the user actually is.
- **Hover, active/pressed, and focus states exist on every interactive
  element.** Focus is an accessibility requirement, not a style choice — see
  [`a11y.mini.md`](./a11y.mini.md), which owns the focus/live-region contract;
  this rule does not duplicate it.

## See also

- [`error-handling.mini.md`](./error-handling.mini.md) — the code-level rule
  this one surfaces to the user.
- [`a11y.mini.md`](./a11y.mini.md) — focus order, live regions, and the
  keyboard/screen-reader side of state changes.

## Provenance

Adapted from `elayadesign/ai-design-skills` (MIT), skill `landing-page-design`,
section B9 "States". The skill as a whole was evaluated and not adopted — see
[`external/plugins-excluded.json`](../external/plugins-excluded.json) — this
generalized, stack-agnostic piece (state completeness, not the landing-page-
specific visual system around it) had no ai-kit equivalent.
