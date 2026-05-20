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
   - If `$AI_KIT_ROOT/bin/usage-stats.sh` is available and the log has events, also run `usage-stats.sh --since=7d` (or `30d`) and surface: top skills used, skills with high abandon-%. Mention this BEFORE asking open questions — it grounds the conversation in observed behaviour.
   - **Finding:** list increments delivered + observed skill usage
   - **Question:** anything missing from this list? Any skill that felt off?

2. **What blocked us**
   - Explore: open issues, reopened bugs, long-running PRs
   - **Finding:** patterns (unclear requirements, missing tests, infra, dependencies)
   - **Question:** top blocker to address next cycle?

3. **Feedback**
   - **Question:** user/stakeholder feedback (you provide — agent does not invent user sentiment)
   - Capture verbatim or summarised

4. **Learnings**
   - Should anything update `CONTEXT.md` or a new ADR?
   - If usage-stats showed a high abandon-% on a skill: ask why the user backed out, and whether the skill itself needs adjusting (e.g. open an issue with template `skill-suggestion`).
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

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" retro start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" retro done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

