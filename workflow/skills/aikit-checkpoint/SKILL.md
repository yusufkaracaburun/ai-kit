---
name: aikit-checkpoint
description: "Save a session-continuation memo to project memory before /clear, /compact, a long break, or end of session. The next session reads the memo and resumes without context-recovery overhead. Use when context is getting big, before clearing or compacting, before pausing work, or when wrapping up for the day."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

<objective>
Write a structured "session-checkpoint" memo to the user's auto-memory folder
for the **current project**, so the next session reads it + `MEMORY.md` and
continues without context-recovery overhead.

You are NOT clearing context. You are NOT auto-running /clear or /compact.
You write the memo, briefly confirm where it landed, and stop. The user runs
/clear (or /compact, or simply leaves) themselves.
</objective>

<other_skills_in_this_space>

`/aikit-checkpoint` is one of three related skills. Pick the right one before
writing anything:

- **`/aikit-checkpoint`** (this skill) — writes to the user's auto-memory folder
  (`~/.claude/.../memory/project/`). For *future you* in the same project.
  Pairs with `/aikit-resume`. Persists across sessions on the same machine.
- **`/aikit-handoff`** — writes to `$TMPDIR/handoff-*.md`. For another agent,
  another machine, or a teammate. Includes redaction. Use this when work
  leaves your machine.
- **`/gsd-pause-work`** — writes `.continue-here.md` *into the project repo*
  with a WIP commit. Use this in GSD projects (those with `.planning/` or
  `STATE.md`). Pairs with `/gsd-resume-work`.

If the project has `.planning/` or `STATE.md` and you do not have a strong
reason to override, stop and route the user to `/gsd-pause-work` instead.

</other_skills_in_this_space>

<process>

## 1. Locate the project memory folder

The auto-memory system prompt typically surfaces the path. Otherwise derive
it: replace `/` with `-` in the absolute working directory, prefix with `-`,
then build `$HOME/.claude/projects/<encoded>/memory/`.

Edge cases:

- **Memory folder missing**: tell the user the auto-memory system is not
  initialised for this project — `/aikit-checkpoint` only makes sense when there
  is already a memory folder. Suggest they enable auto-memory first.
- **Not a git repo**: that is fine. Skip the git-derived fields in the
  memo (`Branch`, `commits ahead`) and note "(no git)" so the next session
  knows to expect no SHAs.
- **GSD project detected** (`.planning/` or `STATE.md` exists): route to
  `/gsd-pause-work` per the disambiguation block above. Do not write a
  generic checkpoint alongside a GSD pause-doc unless the user insists.

## 2. Gather what to capture

Look at the conversation to extract — without re-running expensive tool calls:

- **Branch / phase** — git branch (`git branch --show-current`), and which
  numbered phase or task-ID the session was working on (T-5.5, Phase 7, etc.).
- **Done this session** — completed atomic units. Prefer concrete artefacts:
  commit SHAs from `git log <branch> ^master --oneline | head`; tasks marked
  `completed` via TaskList.
- **Open / next** — what was about to be done when the user invoked
  /aikit-checkpoint. Be specific: "T-5.6 enrollments port — start by reading
  frontend/src/features/admin/pages/enrollments/index.tsx".
- **Blockers / mid-state** — uncommitted changes (`git status --short`),
  failed tests, lint errors the user accepted as "fix later", unresolved
  questions, plan deviations not yet documented.
- **Continuation hints** — exact file paths, line numbers, decision points
  the next session needs. The bar: a fresh Claude reading only the memo
  + `MEMORY.md` should be able to resume in one prompt.

If something is genuinely unknown ("unclear if X works"), write that — the
memo is a checkpoint, not a marketing brochure.

## 3. Write the memo

**Path:** `<memory_dir>/project/session-checkpoint-<YYYY-MM-DD>-<short-slug>.md`

Where `<short-slug>` is a 2-5 word kebab-case summary of the session
(`portal-admin-activities-port`, `seo-meta-fix`, etc.).

**Slug collisions on the same day**:

- Same slug, same topic → overwrite. One checkpoint per sub-topic per day.
- Same slug, *different* topic → pick a more specific slug. Do NOT silently
  overwrite an unrelated checkpoint.
- Multiple parallel topics in one session → write multiple checkpoints, one
  per topic. Each gets its own slug + its own `MEMORY.md` index line.

**Frontmatter:**

```markdown
---
name: Session checkpoint — <one-line topic>
description: <one sentence: what state the project is in after this session>
type: project
---
```

**Body sections** (skip empty ones, never pad):

```markdown
## Where we are
- Branch: `<branch>` (off <base>, <N> commits ahead) — or `(no git)`
- Phase / task: <T-x.y or phase name>

## Done this session
- <concrete artefact 1> (<commit-sha>)
- <concrete artefact 2>
- ...

## Open / next
- <next concrete step with file paths>
- ...

## Blockers / mid-state
- <uncommitted files, failed tests, deferred decisions, etc.>

## Continuation hint for next Claude
<3-6 lines: what to read first, where the work resumes,
which architectural decisions are already locked, what the user wants
verified or still ambiguous.>
```

Keep it scannable: bullets > paragraphs, exact paths > prose, file:line
> "the X module".

## 4. Update `MEMORY.md` index — and auto-flag stale entries

Add one line to `<memory_dir>/MEMORY.md` under a `## Session checkpoints`
section (create the section if it doesn't exist; create the file itself
if it doesn't exist either — frontmatter is not required for `MEMORY.md`):

```markdown
- [<topic> — <date>](project/session-checkpoint-<date>-<slug>.md) — <one-line hook>
```

**While you are in there, auto-flag stale entries.** For each existing line
under `## Session checkpoints`, look at the linked file's `Branch:` field.
If that branch no longer exists locally **and** has no remote (`git
show-ref --verify refs/heads/<branch>` and `git ls-remote --exit-code
--heads origin <branch>` both fail), prepend `[stale]` to that line:

```markdown
- [stale] [<topic> — <date>](project/...) — <one-line hook>
```

Do not delete stale lines — `/aikit-resume` skips them but they remain visible
history. If the user explicitly asks to prune stale entries, do that as a
separate action.

Keep `MEMORY.md` lean — the file is loaded into every conversation, so
each checkpoint line stays one-liner.

## 5. Self-check before confirming

Before printing "Checkpoint saved", silently verify the memo is useful:

- The body contains at least `## Where we are` AND `## Open / next`.
- Total body bullets across all sections ≥ 3.
- At least one concrete reference: a commit SHA (`[0-9a-f]{7,}`),
  a file path with extension, or a `file:line` reference.

If any check fails, regenerate the sparse sections — do NOT ship a hollow
memo. A hollow checkpoint is worse than no checkpoint because it gives
false confidence that the session was captured.

## 6. Confirm and stop

Print to the user: "Checkpoint saved: `<relative-path>`. You can run /clear
(or /compact) now." Do NOT run /clear yourself — that is user discretion.

</process>

<style>

- The memo is for *future you* with zero conversation history. Write so it
  reads cold: no "as discussed", no "you remember", no implicit references.
- Cite SHAs and file paths. Don't paraphrase them into prose.
- Don't capture chitchat, dead ends, or rabbit holes that did not change
  the project state. Capture state changes only.
- If the session was tiny (1-2 commits, no new decisions), say so and
  point at the commit messages instead of duplicating them.

### Example — what good and bad look like

**GOOD:**

```markdown
## Done this session
- Ported activities list to new tenant-admin layout (commit `38794c4`).
  Replaces `ComingSoonShell` at `portal/app/tenant-admin/admin/(protected)/activities/page.tsx`.
- Added filter chips + URL-state sync (`38794c4` + `9a1f0c2`).

## Open / next
- T-5.6 enrollments port — start by reading
  `frontend/src/features/admin/pages/enrollments/index.tsx` (~line 124).
- Decide whether to extract `<FilterChips>` to shared/ — defer until
  enrollments port confirms the second use site.
```

**BAD** (vague, no anchors, hollow):

```markdown
## Done this session
- Made progress on the admin section
- Fixed some stuff with the filters
- Discussed the next steps

## Open / next
- Continue with the porting work
- Look at the other pages too
```

The bad version triggers the self-check failure (no SHAs, no paths, fewer
than 3 concrete references). Regenerate it instead of shipping it.

</style>

<output>

After writing, return one short paragraph:

```
Checkpoint saved → <path>
MEMORY.md updated (stale entries auto-flagged: <N>).
Next session: /aikit-resume — or read that file + MEMORY.md and pick up from
"Open / next".

You can run /clear (or /compact) now.
```

That's it. No further work, no auto-clear, no other side effects.

</output>
