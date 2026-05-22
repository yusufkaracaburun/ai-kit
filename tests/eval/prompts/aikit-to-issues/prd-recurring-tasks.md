---
id: prd-recurring-tasks
skill: aikit-to-issues
expects:
  - breaks the plan into vertical slices (each cuts through ALL layers)
  - labels each slice AFK or HITL, prefers AFK
  - lists dependencies between slices explicitly (blocked-by)
  - issue titles use the project's domain vocabulary and respect ADRs
  - branch-name suggestions follow the git-hygiene rule (feat/, fix/, etc.)
---

# Prompt

We approved the recurring-tasks PRD this morning. Break it into issues so
two AFK agents can start in parallel tomorrow. The PRD is at
docs/prd/recurring-tasks.md.
