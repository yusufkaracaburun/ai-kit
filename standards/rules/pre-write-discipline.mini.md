---
name: pre-write-discipline
description: Four gates before the first edit — assumptions, minimum diff, surgical scope, verifiable goal
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Pre-write discipline

Prevention beats cure. These four gates run *before* the first `Edit` / `Write` of a non-trivial change — not as a refactor pass afterwards, when the speculative abstraction is already merged and someone has to argue it back out.

Applies to any change ≥ 10 LOC or any new file.

## Primary bias to correct

Agents produce more than they were asked for. Extra flags "for flexibility," an abstraction for the second caller that never arrives, error handling for states the type system already excludes, a drive-by cleanup of the function next door. Each addition looks harmless and locally defensible; the sum is a diff the user did not ask for and now has to review.

## The four gates

1. **State assumptions.** Write down what you are assuming. If the request admits more than one reading, surface both — do not silently pick. If it is genuinely unclear, stop and ask; a question costs one turn, a wrong build costs the session.
2. **Minimum diff.** What is the smallest change that solves the problem *as asked*? Cut every flag, abstraction, helper, and branch that was not requested. Ask: "would a senior engineer call this overcomplicated?" If yes, cut more.
3. **Surgical scope.** Every changed line traces back to the request. No drive-by formatting, no adjacent "while I'm here" improvements, no refactoring code you merely happened to read.
4. **Verifiable goal.** State success as something you can *check* — a test passes, a command exits 0, a file contains a string. Then loop until it is verified. "Make it work" is not a goal; it guarantees another round of clarification.

## Anti-patterns

- Adding a `--foo` flag nobody asked for, justified as "future flexibility."
- Introducing an interface, factory, or strategy for a single implementation.
- Multi-category output buckets where a flat list answers the question.
- Error handling for impossible states — trust internal callers and framework guarantees.
- Comments restating what well-named code already says.
- "Improving" code adjacent to the change because you noticed it.
- Reporting a change as done without running the check that would prove it.

## Trigger rules

- **Before the first `Edit` / `Write` of a non-trivial change** — say in one line which gates the change passes. If a gate cannot be justified, fix the design before writing.
- **When the diff grows past what was asked** — stop and cut back, do not rationalise forward.
- **When you are about to add an abstraction** — name its second caller. If you cannot, do not add it.
- **When the task is trivial** (typo, one-liner, mechanical rename) — skip the ceremony. These gates guard against drift, not against typing.

## Trade-off

This biases toward caution over speed. That is deliberate: an unrequested abstraction survives far longer than a slow turn.

## Final checklist before the first write

- Assumptions stated?
- Is this the smallest diff that solves the asked problem?
- Does every changed line trace to the request?
- Can I name the command or test that proves it done?

## See also

- `context-discipline.mini.md` — the same discipline applied to *reading* rather than writing.
- `pragmatic.nano.md` — reversible choices, thin slices, one authoritative source.

Adapted from the four rules in [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills), derived from Andrej Karpathy's observations on LLM coding pitfalls.
