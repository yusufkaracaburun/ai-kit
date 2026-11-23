---
name: grill-with-docs
description: Interview the user relentlessly about a plan or design until shared understanding, challenging it against the domain model and writing terms and decisions to CONTEXT.md, ADRs and docs/decisions.md as they settle, creating those files when missing. Use when the user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
model: fable
---

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing, or ask one frontier round (below).

If a question can be answered by exploring the codebase, explore the codebase instead. For wide sweeps, delegate to a sub-agent (`Explore`) so raw findings stay out of this conversation's context — see [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

Every grill writes docs. If the repo has none yet, create `CONTEXT.md` at the first resolved term and `docs/decisions.md` at the first decision, so nothing decided stays in chat only. `docs/adr/` waits for the first real ADR.

See [DEEPENING.md](DEEPENING.md) for worked question chains for PRD, ADR, design, migration and scope-cut grilling.

## Process

1. **Scope the tree.** Before the first question, restate in one sentence what is being grilled and why, then list the 3 to 7 top-level branches you will walk (for a feature: constraints, user model, data shape, failure modes, rollout, what we are not doing). Settle branches the codebase answers first and report what you found.
2. **Walk one branch at a time.** One concrete question, no compound sub-questions, with your recommended answer and a one-line why, worded so "yes" accepts it. Wait. A new sub-branch goes onto the agenda, announced out loud. A vague answer gets the smallest follow-up that pins it down ("what would make you choose differently?").
3. **Frontier round (optional).** When several questions no longer hang on any open answer, ask them as one numbered batch, each with its recommendation, then recompute the batch from the answers; a question that depends on another one in the batch waits for the next round. Send a wide fact lookup to the `explore` subagent and ask the questions that do not depend on it meanwhile. In this mode the grill is done when no unblocked question is left. Ideas from mattpocock/skills abeeaf9.
4. **Converge.** Summarise the decisions and their reasons in 5 to 15 bullets and ask "Anything that feels wrong now that you see it written down?" Then route on: [to-prd](../to-prd/SKILL.md), [to-issues](../to-issues/SKILL.md), or an ADR.

Anti-patterns: compound questions, open-ended "what do you think about X?", grilling the UI before the data model is settled, stopping at the first plausible answer, and not saying which questions you settled from the code.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Append decisions to docs/decisions.md

When a decision settles, append one line to the project's `docs/decisions.md` right there: `- YYYY-MM-DD: <decision> (source: <grill topic or issue>)`. Append only, never edit an earlier line; create the file if it is absent. Agent Briefs quote these lines under Decisions in force. Terms go to `CONTEXT.md`, decisions go here.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

### Update architecture.md for structure decisions

When a decision changes how frontend or backend code is organized (not just domain terms), update `docs/agents/architecture.md` inline and offer an ADR if the choice is hard to reverse. Create `architecture.md` lazily from `$AI_KIT_ROOT/context/templates/docs/agents/architecture.md` when needed (resolve `AI_KIT_ROOT` from env or `~/.config/ai-kit/root`).

</supporting-info>
