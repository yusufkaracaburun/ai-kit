---
id: start-of-session
skill: resume
required_headings: []
required_keywords:
  - "Resuming"
  - "Branch"
  - "Done"
  - "Open"
  - "Hints"
required_phrases:
  - "Proposed first step"
  - "Ready when you are"
forbidden_keywords:
  - "TODO"
  - "[placeholder]"
  - "I will commit"
  - "I will push"
  - "running it now"
min_lines: 20
max_lines: 120
---

# Hand-written golden output for `resume` / `start-of-session`

Demonstrates the skill at the start of a fresh session. Picks up the
most recent checkpoint, produces the five-line summary, proposes one
concrete first action with file paths, surfaces a branch-mismatch
warning, and waits for confirmation — does not run anything yet.

---

(Quick route check — no `.planning/` or `STATE.md` here, so `/ai:resume` is
correct rather than `/gsd-resume-work`. Memory folder present, one
non-stale checkpoint from yesterday.)

Most recent checkpoint:
`project/session-checkpoint-2026-05-21-admin-section-port.md` (1 day old).

```
Resuming: admin section port (activities done, enrollments next)
Branch:   feat/admin-port  (current branch: master — MISMATCH, see below)
Done:     activities list ported + filter chips (commits 38794c4, 9a1f0c2)
Open:     T-5.6 enrollments port — read enrollments/index.tsx around line 124
Hints:    activities pattern is the template; filter chips inline; nuqs for URL state
```

Proposed first step: switch to `feat/admin-port`, then open
`frontend/src/features/admin/pages/enrollments/index.tsx` and read around
line 124 to see the current placeholder. After that we apply the activities
port pattern (route shell + filter chips + URL state via `nuqs`).

Heads-up: you are currently on `master`, but the memo's work was on
`feat/admin-port`. I will not switch branches automatically — confirm if
you want me to. Working tree is clean, no untracked surprises.

Ready when you are.
