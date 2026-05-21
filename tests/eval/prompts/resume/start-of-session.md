---
id: start-of-session
skill: resume
expects:
  - locates the project's auto-memory folder
  - routes to /gsd-resume-work when the project has .planning/ or STATE.md
  - picks the most recent checkpoint by mtime (skips stale-flagged entries)
  - produces the exact five-line summary shape (Resuming / Branch / Done / Open / Hints)
  - flags branch mismatch if current branch differs from memo's branch
  - flags memos older than 7 days
  - proposes ONE concrete next action with file paths; does NOT run it yet
  - surfaces uncommitted work that the memo did not mention
---

# Prompt

Fresh session, just opened the project. /resume — where was I?
