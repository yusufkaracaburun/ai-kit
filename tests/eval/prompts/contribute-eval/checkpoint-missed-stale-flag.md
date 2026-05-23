---
id: checkpoint-missed-stale-flag
skill: contribute-eval
expects:
  - picks the target skill and rejects a duplicate scenario name
  - captures prompt + actual output + expected-behaviour bullets separately
  - rejects vague expected-behaviour answers and asks for testable phrasing
  - redacts absolute paths / secrets / tenant names before writing files
  - composes both files (prompt fixture + golden rubric) matching the existing format
  - derives rubric fields conservatively from the user's bullets (no invented keywords)
  - shows the full PR body before running `gh pr create`
  - opens one PR, prints the URL, offers --watch
---

# Prompt

/ai:contribute-eval — checkpoint skill missed flagging stale entries. The
memo I got back had a MEMORY.md reference but did NOT mark the
`feat/legacy-search` line as stale even though that branch was deleted
weeks ago. Add a regression case so this doesn't happen again.

Skill: checkpoint
Scenario name: missed-stale-flag

The actual output was a checkpoint memo that included MEMORY.md verbatim,
no stale markers. What I expected:

- enumerates branches mentioned in MEMORY.md
- checks each branch still exists locally or on the remote
- flags missing branches as [stale]
- prints a stale-count summary line
