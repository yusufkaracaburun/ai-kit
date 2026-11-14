---
id: monthly-run
skill: workflow-audit
expects:
  - finds the newest docs/audits/workflow-audit-*.md and uses its date as the since-date
  - spawns three subagent_type=ai:explore agents in one message, one per brief
  - waits for all three before merging
  - writes docs/audits/workflow-audit-<today>.md with every fixed section, Delta included
  - marks a key figure stable, with no slice, when |Δ| ≤ max(1, 10% of the previous value), or ≤ 5 percentage points for percentages
  - marks a figure with no value this run as not measured, never a guess
  - lists a better figure under Resolved with the commit or release that resolved it
  - writes through a general-purpose sonnet agent when the session claim says role=lead
  - asks which slices become issues instead of opening them
---

# Prompt

/ai:next says the last workflow audit was 34 days ago. Run it.
