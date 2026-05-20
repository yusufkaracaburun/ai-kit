---
name: retro
description: Sprint or cycle retrospective — what shipped, what blocked, stakeholder feedback, learnings, next backlog. Use at end of a sprint or release cycle. Works for Scrum and Kanban.
---

# Retrospective

Close the agile loop: review what happened, capture learnings, plan the next cycle.

See `docs/agents/workflow.md` for Scrum vs Kanban context.

## Process

Ask **one topic at a time** (grill-me-lite). Provide a recommendation based on git/issue history before each question.

1. **What shipped**
   - Explore: merged PRs, closed issues, tags since last retro (or last 1–4 weeks)
   - **Finding:** list increments delivered
   - **Question:** anything missing from this list?

2. **What blocked us**
   - Explore: open issues, reopened bugs, long-running PRs
   - **Finding:** patterns (unclear requirements, missing tests, infra, dependencies)
   - **Question:** top blocker to address next cycle?

3. **Feedback**
   - **Question:** user/stakeholder feedback (you provide — agent does not invent user sentiment)
   - Capture verbatim or summarised

4. **Learnings**
   - Should anything update `CONTEXT.md` or a new ADR?
   - Only write docs if the user agrees

5. **Next cycle**
   - Propose 3–5 backlog items ranked by impact
   - Offer to run `to-issues` if user wants tickets created

## Output

```markdown
## Shipped
- ...

## Blockers
- ...

## Feedback
- ...

## Learnings
- ...

## Next cycle (proposed)
1. ...
2. ...

## Actions
- [ ] Update CONTEXT.md / ADR (if agreed)
- [ ] Create issues via to-issues (if requested)
```

Works without fixed sprint length — Kanban teams run `/retro` on a rhythm they choose.
