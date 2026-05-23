---
id: before-clear
skill: checkpoint
required_headings:
  - "## Where we are"
  - "## Done this session"
  - "## Open / next"
  - "## Continuation hint for next Claude"
required_keywords:
  - "MEMORY.md"
  - "stale"
  - "commit"
required_phrases:
  - "Checkpoint saved"
  - "You can run /clear"
forbidden_keywords:
  - "TODO"
  - "FIXME"
  - "[placeholder]"
  - "made progress"
  - "fixed some stuff"
min_lines: 30
max_lines: 200
---

# Hand-written golden output for `checkpoint` / `before-clear`

Demonstrates the skill on a typical end-of-session call: clean working tree,
two artefacts shipped, one open task with a concrete file:line anchor, one
deferred decision. The memo must hit the self-check (≥3 bullets, ≥1 concrete
reference, both required sections) and the response must explicitly NOT run
/clear itself.

---

(Quick route check — no `.planning/` or `STATE.md` in this project, so I'm
using `/ai:checkpoint` rather than `/gsd-pause-work`. Auto-memory folder
present at the expected path.)

I'll write the memo to
`~/.claude/projects/<encoded-cwd>/memory/project/session-checkpoint-2026-05-21-admin-section-port.md`:

```markdown
---
name: Session checkpoint — admin section port (activities done, enrollments next)
description: Activities list ported to new layout; enrollments queued at index.tsx:124; one deferred extraction call.
type: project
---

## Where we are
- Branch: `feat/admin-port` (off `master`, 2 commits ahead)
- Phase / task: admin section port — T-5.5 done, T-5.6 next

## Done this session
- Ported activities list to new tenant-admin layout (commit `38794c4`).
  Replaces `ComingSoonShell` at
  `portal/app/tenant-admin/admin/(protected)/activities/page.tsx`.
- Added filter chips + URL-state sync (commits `38794c4` + `9a1f0c2`).

## Open / next
- T-5.6 enrollments port — start by reading
  `frontend/src/features/admin/pages/enrollments/index.tsx` around line 124.
- Decide whether to extract `<FilterChips>` to `shared/` — defer until the
  enrollments port confirms the second use site.

## Blockers / mid-state
- (none — working tree clean, no failing tests)

## Continuation hint for next Claude
The activities port pattern (route shell + filter chips + URL state) is the
template for enrollments. Decisions already locked: filter chips render
inline (no popover), URL state uses `nuqs`. Open question for the user:
should the chips component live next to enrollments or move to `shared/`
now? Defer until you can see the duplication.
```

I also updated `MEMORY.md` and walked the existing checkpoint index. One
older entry pointed at `feat/legacy-search` — that branch no longer exists
locally and has no remote, so I flagged it with `[stale]` (kept the line
for history, did not delete it).

Self-check before saving: memo contains `## Where we are` and `## Open / next`,
five bullets total across sections, three concrete references (two SHAs +
one file:line). All checks pass.

Checkpoint saved → `project/session-checkpoint-2026-05-21-admin-section-port.md`
MEMORY.md updated (stale entries auto-flagged: 1).
Next session: `/ai:resume` — or read that file + MEMORY.md and pick up from
"Open / next".

You can run /clear (or /compact) now.
