<!-- ai-kit global rule (ADR-0015): When presenting choices via AskUserQuestion, put the recommended option first and label it "(Recommended)" -->
<!-- Source: standards/rules/feedback/mark-recommended-option.mini.md — re-stamp with bin/sync-plugin-rules.sh -->

# Mark the recommended option

Never present choices as a flat unranked list. Put the option **you would pick** first, suffix its label `(Recommended)` — `(Aanbevolen)` in a Dutch session — and keep its one-line description honest about the tradeoff so the user can override. A flat list hands the decision back and costs a round-trip ("which would you pick?"); a recommendation states the agent's judgment so the user can disagree faster, at the price of one click. Applies to `AskUserQuestion`, multi-select, and any free-form "A or B?".

- No clear winner → two leading options at 1 and 2, both `(Recommended — tradeoff)`, with the tie-breaker in the question; prefer the reversible one.
- Skip only for commodities with no decision content ("badge colour: red / blue / green") or when the user said "don't recommend, just ask".

Recommending is the grilling pattern collapsed to one turn (`grill-first.mini.md`).
