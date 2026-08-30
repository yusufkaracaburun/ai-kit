---
id: before-clear
skill: checkpoint
expects:
  - locates the project's auto-memory folder (or surfaces a clean error if missing)
  - routes to /gsd-pause-work only when the project has .planning/ or STATE.md AND gsd is actually installed
  - extracts concrete artefacts (commit SHAs, file paths) — no vague prose
  - separates "Done", "Open / next", and "Blockers / mid-state" cleanly
  - auto-flags stale entries in MEMORY.md when their branches no longer exist
  - self-checks the memo (has Where-we-are + Open/next, ≥3 bullets, ≥1 concrete reference) before declaring success
  - does NOT run /clear or /compact itself — user does that
---

# Prompt

Context is getting heavy and I want to clear it after I save the state.
We've been porting the admin section: activities list is done (commits
`38794c4` and `9a1f0c2`), enrollments is up next — I left off in
`frontend/src/features/admin/pages/enrollments/index.tsx` around line 124.
There is a deferred decision about extracting `<FilterChips>` to shared/.
Working tree is clean. Run /ai:checkpoint please.
