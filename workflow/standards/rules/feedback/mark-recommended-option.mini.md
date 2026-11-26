---
name: mark-recommended-option
description: Ask every question or choice through AskUserQuestion, recommended option first and labelled "(Recommended)"
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---
# Mark the recommended option

Never present choices as a flat unranked list. Put the option **you would pick** first, suffix its label `(Recommended)` — `(Aanbevolen)` in a Dutch session — and keep its one-line description honest about the tradeoff so the user can override. A flat list hands the decision back and costs a round-trip ("which would you pick?"); a recommendation states the agent's judgment so the user can disagree faster, at the price of one click. Applies to every `AskUserQuestion` and multi-select, and to grill's ❓/➡️ prose questions.

- Every question or choice for the user goes through `AskUserQuestion` where the host offers it, a single one included; a question asked only in prose is a defect, except grill's ❓/➡️ question format.
- No clear winner → two leading options at 1 and 2, both `(Recommended — tradeoff)`, with the tie-breaker in the question; prefer the reversible one.
- Skip only for commodities with no decision content ("badge colour: red / blue / green") or when the user said "don't recommend, just ask".
- When a turn asks the user something, the recommendation also stands in that turn's prose, not only in the `AskUserQuestion` labels. The user typing "advies?" means this rule was missed.
- An option that adds or keeps behaviour states its measured use (count, period, source) and that the backend supports it, both checked before you ask. Not measurable: say so and why.
- One option decides one feature; never drop several features in one option.
- An item the user may not know: one sentence on what it is, one on what works today, one on what is missing, then the options.
- A question that reopens a recorded decision quotes that decision with its date.

Recommending is the grilling pattern collapsed to one turn (`grill-first.mini.md`).
