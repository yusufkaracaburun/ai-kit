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

Four gates before the first `Edit` / `Write` of any change ≥ 10 LOC or any new file — not a refactor pass afterwards, when the speculative abstraction is merged and someone has to argue it back out. The bias to correct: agents produce more than asked — a flag "for flexibility", an abstraction for a second caller that never arrives, error handling for states the types already exclude, a drive-by cleanup next door. Each looks harmless; the sum is a diff the user did not ask for and now has to review.

## The four gates

1. **State assumptions.** Write down what you are assuming. More than one reading → surface both, never pick silently. Genuinely unclear → ask; a question costs one turn, a wrong build costs the session.
2. **Minimum diff.** The smallest change that solves the problem *as asked*. Cut every flag, abstraction, helper and branch not requested. "Would a senior engineer call this overcomplicated?" — if yes, cut more.
3. **Surgical scope.** Every changed line traces to the request. No drive-by formatting, no "while I'm here", no refactoring code you merely read.
4. **Verifiable goal.** Success is something you can *check* — a test passes, a command exits 0, a file contains a string — then loop until verified. "Make it work" guarantees another round of clarification.

## Anti-patterns

A `--foo` flag nobody asked for · an interface/factory/strategy with one implementation (name the second caller or don't add it) · multi-category output where a flat list answers · error handling for impossible states · comments restating well-named code · "improving" adjacent code · reporting done without running the check that proves it.

## Triggers

- Before the first `Edit` / `Write` of a non-trivial change: one line naming which gates it passes. A gate you cannot justify → fix the design first.
- The diff grows past what was asked → stop and cut back, do not rationalise forward.
- Trivial task (typo, one-liner, mechanical rename) → skip the ceremony; the gates guard against drift, not typing.

Biases toward caution over speed, deliberately: an unrequested abstraction outlives a slow turn.

See `context-discipline.mini.md` (the same discipline for reading) and the `ponytail` companion (the YAGNI ladder, injected at session and subagent start on Claude Code). Adapted from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills), after Andrej Karpathy's observations on LLM coding pitfalls.
