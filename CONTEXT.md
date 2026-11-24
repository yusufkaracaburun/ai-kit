# ai-kit

The words ai-kit uses for the cards its skills create on an issue tracker.

## Language

### Layers

**Epic**:
A large capability that consists of **Stories**.
_Avoid_: Feature

**PRD**:
The worked-out text of one **Epic**.

**Story**:
One deliverable piece of work. It belongs to at most one **Epic** and has zero or more **Subtasks**.
_Avoid_: Feature, slice, ticket

**Task**:
Small maintenance that belongs to no **Story**.
_Avoid_: Chore

**Subtask**:
A piece of one **Story**: a checkbox there, or its own sub-issue when it ships separately or another executor takes it.

**Bug**:
A fault: something does not work as it should.
_Avoid_: Defect

### Card kinds outside the layers

**Spike**:
Time-boxed research or a proof of concept.

**Idea**:
Something not decided or not started. Picked up, it becomes a **Story**, **Task**, **Bug** or **Spike**; a known fault is always a **Bug**.
_Avoid_: Defer, follow-up

### Cutting work

**Vertical slice**:
The technique of cutting work through every layer end to end. What it yields is a **Story**.

## Flagged ambiguities

- "Feature" meant both the large capability and the deliverable piece. Resolved: the first is an **Epic**, the second a **Story**.
- "Slice" meant both the technique and the card. Resolved: **Vertical slice** is the technique, the card is a **Story**.
- "Idea" in the `validate-idea` skill is a new product, not this card.
- Waiting is a board column (Backlog), not a card kind.

## Example dialogue

> **Dev:** "Recurring tasks is a big feature. One card?"
> **Maintainer:** "That is an **Epic**; its **PRD** is the text on the card. Cut it into **Stories**."
> **Dev:** "And the migration inside the first one?"
> **Maintainer:** "A **Subtask**, so a checkbox, unless someone else picks it up."
