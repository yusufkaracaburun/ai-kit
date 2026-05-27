---
name: checkpoint
description: "Compact the current session for resumption. Default writes to project auto-memory for same-project, same-machine resume (pairs with /ai:resume). Pass --to tmp to write a transfer briefing to $TMPDIR for another agent, machine, or teammate (includes redaction). Pass --mid-session to compact in place without /clear. Use when context is getting big, before clearing or compacting, before pausing, when wrapping up, or when handing work off."
argument-hint: "[slug] [--to memory|tmp] [--mid-session]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

<objective>
Write a structured session-continuation memo so the next session (you, another
agent, or a teammate) can resume without context-recovery overhead.

You are NOT clearing context. You are NOT auto-running /clear or /compact.
You write the memo, briefly confirm where it landed, and stop. The user runs
/clear (or /compact, or simply leaves) themselves — except in `--mid-session`
mode, where there is no clear at all.
</objective>

<other_skills_in_this_space>

- **`/ai:checkpoint`** (this skill) — default `--to memory` writes to the
  user's auto-memory folder (`~/.claude/.../memory/project/`), for *future
  you* in the same project; pairs with `/ai:resume`. `--to tmp` writes a
  transfer briefing to `$TMPDIR` for another agent, machine, or teammate,
  with redaction always-on.
- **`/gsd-pause-work`** — writes `.continue-here.md` *into the project repo*
  with a WIP commit. Use this in GSD projects (those with `.planning/` or
  `STATE.md`). Pairs with `/gsd-resume-work`. The `--to memory` path here
  routes to it automatically.

If the project has `.planning/` or `STATE.md` and `--to memory` is selected
and you do not have a strong reason to override, stop and route the user to
`/gsd-pause-work` instead. `--to tmp` is not GSD-routed — a transfer
briefing crosses the machine boundary, GSD pause-docs do not.

</other_skills_in_this_space>

<args>

Parse the slash arguments before anything else:

- `[slug]` (positional) — 2-5 word kebab-case topic. If absent, derive from the
  conversation.
- `--to memory|tmp` — destination. Default `memory`.
- `--mid-session` — compact without ending the session; the user explicitly
  stays in this conversation.

If `--to` value is anything other than `memory` or `tmp`, stop and ask. Never
silently default away from an explicit user choice.

</args>

<process>

## 1. Branch on `--to`

- **`--to memory`** (default): follow §2-§7 below — write to project
  auto-memory, update MEMORY.md, fire docs-sync nudge.
- **`--to tmp`**: skip to §8 — write a transfer briefing to `$TMPDIR`, with
  redaction always-on. No MEMORY.md update, no docs-sync nudge, no GSD
  routing.

## 2. Locate the project memory folder

The auto-memory system prompt typically surfaces the path. Otherwise derive
it: replace `/` with `-` in the absolute working directory, prefix with `-`,
then build `$HOME/.claude/projects/<encoded>/memory/`.

Edge cases:

- **Memory folder missing**: tell the user the auto-memory system is not
  initialised for this project — `--to memory` only makes sense when there
  is already a memory folder. Suggest they enable auto-memory first, or
  re-run with `--to tmp`.
- **Not a git repo**: that is fine. Skip the git-derived fields in the
  memo (`Branch`, `commits ahead`) and note "(no git)" so the next session
  knows to expect no SHAs.
- **GSD project detected** (`.planning/` or `STATE.md` exists): route to
  `/gsd-pause-work` per the disambiguation block above. Do not write a
  generic checkpoint alongside a GSD pause-doc unless the user insists.

## 3. Gather what to capture

Look at the conversation to extract — without re-running expensive tool calls:

- **Branch / phase** — git branch (`git branch --show-current`), and which
  numbered phase or task-ID the session was working on (T-5.5, Phase 7, etc.).
- **Done this session** — completed atomic units. Prefer concrete artefacts:
  commit SHAs from `git log <branch> ^master --oneline | head`; tasks marked
  `completed` via TaskList.
- **Open / next** — what was about to be done when the user invoked
  /ai:checkpoint. Be specific: "T-5.6 enrollments port — start by reading
  frontend/src/features/admin/pages/enrollments/index.tsx".
- **Blockers / mid-state** — uncommitted changes (`git status --short`),
  failed tests, lint errors the user accepted as "fix later", unresolved
  questions, plan deviations not yet documented.
- **Continuation hints** — exact file paths, line numbers, decision points
  the next session needs. The bar: a fresh Claude reading only the memo
  + `MEMORY.md` should be able to resume in one prompt.

If something is genuinely unknown ("unclear if X works"), write that — the
memo is a checkpoint, not a marketing brochure.

## 4. Write the memo

**Path:** `<memory_dir>/project/session-checkpoint-<YYYY-MM-DD>-<short-slug>.md`

Where `<short-slug>` is from the positional arg or a 2-5 word kebab-case
summary of the session (`portal-admin-activities-port`, `seo-meta-fix`, etc.).

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

## 5. Update `MEMORY.md` index — and auto-flag stale entries

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

Do not delete stale lines — `/ai:resume` skips them but they remain visible
history. If the user explicitly asks to prune stale entries, do that as a
separate action.

Keep `MEMORY.md` lean — the file is loaded into every conversation, so
each checkpoint line stays one-liner.

## 6. Self-check before confirming

Before printing "Checkpoint saved", silently verify the memo is useful:

- The body contains at least `## Where we are` AND `## Open / next`.
- Total body bullets across all sections ≥ 3.
- At least one concrete reference: a commit SHA (`[0-9a-f]{7,}`),
  a file path with extension, or a `file:line` reference.

If any check fails, regenerate the sparse sections — do NOT ship a hollow
memo. A hollow checkpoint is worse than no checkpoint because it gives
false confidence that the session was captured.

## 7. Confirm, fire cross-cue, stop

Before printing the final confirmation, run the cross-cue helper:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-docs-sync-nudge.sh" "<project_path>" --context=checkpoint
```

It prints a small "Before clear, consider:" block listing `/ai:hygiene`
(install + framework wiring health) and/or `/ai:docs-sync` (content drift —
dead links, repo-hygiene, finished-work cleanup) **only when applicable**:

- `/ai:hygiene` shown when `.ai-kit-setup` marker exists in the project.
- `/ai:docs-sync` shown when the project has a `docs/` dir, any `*.md` file, or more than one local branch.

If neither applies the helper prints nothing — surface nothing in that
case. The helper is fast (<50ms on a typical repo) and reuses the central
applicability functions in `bin/lib/applicability.sh`, so checkpoint /
ship / triage all stay in sync.

Then print: "Checkpoint saved: `<relative-path>`. You can run /clear
(or /compact) now."

In `--mid-session` mode: same memo, same path, but print "Checkpoint saved
(mid-session): `<relative-path>`. Continue in this session — focus on the
next 1-3 items from Open/next; defer the rest to the doc." Do NOT suggest
/clear.

## 8. `--to tmp` path — transfer briefing

This path replaces §2-§7. Write a transfer briefing for another agent,
machine, or teammate.

### 8.1 Locate prior artefacts

Identify PRDs, plans, ADRs, issues, commits, and diffs that already capture
parts of the work. The briefing *references* these by path or URL, never
duplicates their content. Duplication rots fast.

### 8.2 Pick the temp path

```bash
mktemp "${TMPDIR:-/tmp}/handoff-XXXXXX.md"
```

Two parallel briefings won't collide. The historic filename prefix
`handoff-` is preserved so existing tooling and muscle memory still work.

### 8.3 Write the briefing

```markdown
# Handoff: <one-line focus>

**Created:** <ISO date> · **From:** <project name or repo>
**Next session focus:** <user-provided slug, or your best guess>

## State right now

- What is done, in 3-5 bullets. Reference commits/PRs by hash or number, not by re-explaining.
- What is in-progress, with the exact file/function/line if mid-edit.
- What is blocked and on whom.

## Open questions

- Numbered list. Each question should be answerable in one decision.
- Mark questions the receiving agent can answer themselves vs. ones that need the user.

## Where the truth lives

- PRD: `docs/prd/feature-x.md`
- Plan: `.planning/.../PLAN.md`
- ADRs touched: `docs/adr/000N-*.md`
- Recent commits: `<sha>..<sha>`
- Failing tests: paste output once, link the file.

## Suggested skills for the next session

- `skill-name` — why it fits

## Do NOT

- Specific footguns (e.g. "don't run the seed script — it drops the dev DB").
- Approaches already ruled out, with a one-line reason.
```

Skip sections that don't apply rather than padding with "n/a".

### 8.4 Redact (always-on for `--to tmp`)

Strip:
- Secrets, tokens, API keys, passwords.
- Absolute paths under `/Users/<name>` or `/home/<name>` — use `~/` or a placeholder.
- PII (email addresses, full names not already on the project).
- Stack traces that contain machine-specific paths.

If you are unsure whether something is sensitive, redact. The briefing
crosses the machine boundary; treat it as if it might be pasted into a chat.

### 8.5 What NOT to put in the briefing

- Verbatim copies of the PRD/plan/ADR — link them.
- Decision rationale that already lives in an ADR — reference the ADR number.
- The full diff — reference the commit range.
- Step-by-step instructions for trivial commands the next agent can derive
  (e.g. "run `pnpm install`"). Include only commands that are non-obvious
  or where order matters.
- Conversation transcript — the briefing is the distillation, not the log.
- Wishful thinking. "Should be quick" / "minor fix" are tells that the
  previous session under-investigated. Be honest about uncertainty.

### 8.6 Self-check before confirming

- The body contains at least `## State right now` AND `## Open questions`.
- Total body bullets across all sections ≥ 3.
- At least one concrete reference: a commit SHA, a file path with
  extension, an issue/PR number, or an ADR reference.
- A "Suggested skills" line names at least one slash command the receiving
  agent can run.

### 8.7 Print the path

Show the user the full path so they can copy or move it:

```
Handoff briefing saved → /var/folders/.../handoff-AbC123.md
Suggested next skill on the receiving end: /ai:onboard (project shape) or
re-load this file's "Suggested skills" line.
```

In `--mid-session` mode: same briefing, same path. Add "Continue in this
session — focus on the next 1-3 items from State/Open; the briefing exists
in case the session ends abruptly." Do NOT suggest /clear.

</process>

<style>

- The memo (either target) is for a reader with zero conversation history.
  Write so it reads cold: no "as discussed", no "you remember", no implicit
  references.
- Cite SHAs and file paths. Don't paraphrase them into prose.
- Don't capture chitchat, dead ends, or rabbit holes that did not change
  the project state. Capture state changes only.
- If the session was tiny (1-2 commits, no new decisions), say so and
  point at the commit messages instead of duplicating them.

### Example — what good and bad look like (memory target)

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

**`--to memory`:**

```
Checkpoint saved → <path>
MEMORY.md updated (stale entries auto-flagged: <N>).
Next session: /ai:resume — or read that file + MEMORY.md and pick up from
"Open / next".

You can run /clear (or /compact) now.
```

**`--to tmp`:**

```
Handoff briefing saved → <path>
Redacted: secrets, absolute home paths, PII.
Next session on the receiving end: read that file + run /ai:onboard if
the agent is new to the project.

You can run /clear now (or copy the file off the machine first).
```

In `--mid-session` mode, swap the trailing "/clear" line for: "Continue in
this session — work the next 1-3 items in focus."

</output>
