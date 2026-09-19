---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview the user relentlessly about every aspect of this plan until shared understanding is reached. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask one question at a time. If a question can be answered by exploring the codebase, explore instead.

See [DEEPENING.md](DEEPENING.md) for worked example question chains across PRD, ADR, design, migration, and scope-cut grilling.

## Process

### Phase 1 — Scope the tree

Before the first question, restate in one sentence what is being grilled and why. Then list the **top-level branches** you intend to walk (3–7). This is the agenda; surface it so the user can interrupt or reorder.

A good agenda for a feature plan looks like: *constraints* · *user model* · *data shape* · *failure modes* · *rollout* · *what we're explicitly NOT doing*. For a design doc: *invariants* · *boundaries* · *coupling* · *change vectors*. For an ADR: *forces* · *options* · *consequences* · *reversibility*.

If a branch can be settled from the codebase, settle it silently first and report findings — don't make the user answer questions you could have answered yourself.

### Phase 2 — Walk one branch at a time

For each branch:

1. **Ask the question.** Single, concrete, no compound sub-questions.
2. **Offer your recommended answer** with a one-line *why* — this gives the user something to push against, which is faster than open-ended brainstorming.
3. **Wait.** Don't preempt with the next question.
4. **Resolve before moving on.** If the answer reveals a new sub-branch, push it onto the agenda and announce that explicitly ("That opens a question about X — I'll come back to it after we finish Y").

If the user gives a vague answer, ask the smallest follow-up that pins it down — usually "what would make you choose differently?" or "what does failure look like?".

### Phase 3 — Converge and write back

When all branches are settled, write a short summary (5–15 bullets) of the decisions and their rationale, and ask: "Anything that feels wrong now that you see it written down?" Surprises here are common and cheap to fix; ignore at the user's peril.

Then route to the next skill: usually [to-prd](../to-prd/SKILL.md), [to-issues](../to-issues/SKILL.md), or directly to writing an ADR.

## Anti-patterns

- **Compound questions.** "What's the data model and how will you migrate?" → two branches, two questions.
- **Open-ended brainstorming.** "What do you think about X?" wastes a turn. Recommend, then ask if you're wrong.
- **Walking out of order.** Resolve dependencies first; don't grill the user about a UI when the data model isn't settled.
- **Stopping at the first plausible answer.** Push one level deeper: "what would change that decision?"
- **Forgetting to surface what you settled in the codebase.** The user wants to know which questions you skipped and why.
