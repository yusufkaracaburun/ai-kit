# grill-me — worked examples

Five canonical grilling scenarios. Use them as templates, not scripts — the questions you actually ask depend on what's missing from the user's plan.

## 1. PRD grilling

Top-level branches: *who* · *problem* · *success metric* · *scope cut* · *anti-goals* · *rollout*

Example chain:

1. "Who is the **first user** who must love this — not 'developers,' a specific persona?"
   *Recommended:* the one with the most painful current workaround. *Why:* they'll tolerate a rough v1.
2. "What's the **single sentence** describing the problem we're solving?"
   *Recommended:* a sentence the user could speak out loud; if it needs three clauses, scope is too wide.
3. "What **metric** tells us in 4 weeks whether this worked?"
   *Recommended:* something countable in the existing dashboards. *Why:* if you need to instrument first, you don't have feedback yet.
4. "What's **explicitly not** in v1?" — at least three things.
5. "Ramp: % rollout, who gates it, when do we kill it?"

## 2. ADR grilling

Top-level branches: *forces* · *options considered* · *chosen option* · *consequences* · *reversibility*

Example chain:

1. "What **forces** are pulling this decision? Name at least two competing ones."
   *Recommended:* surface tension first; if there's no tension, the ADR is theatre.
2. "What **3 options** did you consider — not just the one you want?"
3. "What's the **second-best** option, and what would flip you to it?"
4. "What **consequence** of the chosen option will hurt in 6 months?"
5. "Is this **reversible**? If yes, what triggers the reverse? If no, what's the migration cost?"

## 3. Design grilling

Top-level branches: *invariants* · *module boundaries* · *coupling* · *change vectors* · *failure modes*

Example chain:

1. "What's an **invariant** of this system — something that must always be true?"
2. "What happens if a future change **violates that invariant** — how do we detect it?"
3. "Where's the **highest-coupling** edge? What does each side know about the other?"
   *Recommended:* if both sides know each other's internal types, that's the seam to refactor.
4. "Which dimension of change did you **plan for**, and which are you betting won't happen?"
5. "What's the **expected failure mode** of the most fragile module? What does the on-call see?"

## 4. Migration grilling

Top-level branches: *current state* · *target state* · *bridge* · *cutover* · *rollback*

Example chain:

1. "What's the **exact current state** — schema, traffic, dependencies — not the simplified version?"
2. "Does the system need to **serve both old and new** during the migration? For how long?"
3. "What's the **bridge layer**? Is it a feature flag, a dual-write, a shadow read?"
   *Recommended:* dual-write + shadow-read if data is involved. *Why:* lets you compare before cutover.
4. "What's the **cutover signal**? Time-based or metric-based?"
5. "What's the **rollback procedure**, in commands? Have you run it on a staging copy?"

## 5. Scope-cut grilling

Top-level branches: *MVP definition* · *cuts* · *dependencies* · *delivery sequencing*

Example chain:

1. "What's the **smallest thing** we could ship and still claim the problem is solved?"
2. "Which feature on your list is **theatre** — looks valuable, doesn't change the metric?"
3. "What **depends** on what? Draw the DAG, find the longest path."
4. "If we had to ship in **half the time**, what comes out?"
5. "What's the **first thing to ship to a real user** — not the first thing to build?"
   *Recommended:* a thin vertical slice end-to-end beats a complete layer.

## Reading the room

If the user pushes back hard on a question, that's a signal — either you've found load-bearing uncertainty (keep pulling) or the question was off-target (drop it, recalibrate). Don't grind. The goal is shared understanding, not making the user prove themselves.
