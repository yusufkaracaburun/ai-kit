---
name: mark-recommended-option
description: When presenting choices via AskUserQuestion, put the recommended option first and label it "(Recommended)"
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

When asking the user to choose between options, never present them as a
flat unranked list. Always:

1. Put the option **you would pick** at position 1.
2. Suffix its label with `(Recommended)` (or the matching localised
   equivalent — `(Aanbevolen)` for Dutch sessions).
3. Keep the one-line `description` honest about the tradeoff so the
   user can override.

## Why

A flat list of options passes the decision entirely to the user, who
then has to either ask follow-ups ("which would you pick?") or guess.
That round-trip is the actual cost: in a typical session it costs one
extra turn and one re-read of the conversation context.

Surfacing a recommendation is not paternalism — it's stating what the
agent's best judgment is so the user can disagree faster. The user
keeps full override; the cost of a wrong recommendation is one click on
a different option.

The pattern carries across `AskUserQuestion`, multi-select questions,
and any free-form "do you want A or B?" prompt.

## How to apply

```jsonc
// Yes
{
  "options": [
    { "label": "Squash-merge (Recommended)", "description": "..." },
    { "label": "Rebase-merge",               "description": "..." },
    { "label": "Plain merge",                "description": "..." }
  ]
}

// No — no signal, user must guess
{
  "options": [
    { "label": "Squash-merge", "description": "..." },
    { "label": "Rebase-merge", "description": "..." },
    { "label": "Plain merge",  "description": "..." }
  ]
}
```

Edge cases:

- **No clear winner**: present two leading options at positions 1+2,
  both labelled `(Recommended — tradeoff)` with a one-line tie-breaker
  in the question prompt.
- **Reversible vs irreversible**: prefer reversibility as the
  recommendation tie-breaker.
- **Locale**: detect Dutch from prior conversation language; default to
  English suffix otherwise.

## When to skip

- The options are equivalent commodities (e.g. "pick a colour for the
  badge: red / blue / green") with no decision content. Then a flat
  list is honest.
- The user has explicitly said "don't recommend, just ask" for this
  decision.

## See also

- [`grill-first.mini.md`](../grill-first.mini.md) — recommending is the
  grilling pattern collapsed to one turn.
