## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Review before release

Run `/ai:review` before a release, not after it. This repo has one committer,
so nothing else provides a second pass, and a reviewer starting from the diff
catches what the person who wrote it reads past.

## Working principles

**Prevention > cure.** Apply this checklist BEFORE writing code, not as a post-write refactor pass. Score yourself 100/100 each diff.

### Pre-write checklist (mandatory)

For any change ≥ 10 LOC or any new file:

1. **State assumptions.** Write down what you're assuming. If multiple interpretations exist, surface them — don't pick silently. If unclear, stop and ask.
2. **Minimum code.** What's the smallest diff that solves the asked problem? Cut every flag, abstraction, helper, or branch that wasn't requested. "Would a senior engineer say this is overcomplicated?" If yes, cut more.
3. **Surgical scope.** Every changed line traces to the user's request. No drive-by formatting, no adjacent "improvements", no refactoring of unrelated code.
4. **Verifiable goal.** State success as something you can check (test passes, command exits 0, file contains string). Loop until verified. Weak goals ("make it work") = constant clarification.

### Anti-patterns (don't do this)

- Adding `--foo` flags that weren't asked for ("future flexibility")
- Multi-category output buckets when a flat list works
- Error handling for impossible scenarios (trust internal code + framework guarantees)
- Comments explaining what well-named code already says
- "Improving" code adjacent to your change because you noticed it

### Tradeoff

These principles bias toward caution over speed. For trivial tasks (typo fixes, single-line edits) use judgment — the checklist is for changes that risk drift.

### How to apply

Before the first `Edit` / `Write` of a non-trivial change, briefly state in your response which of the 4 the change passes. If you can't justify one, fix the design before writing.
