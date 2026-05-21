---
name: resume
description: "Find the most recent /checkpoint memo for the current project, summarise it, and propose the first concrete action — pick up where you left off. Use at the start of a fresh session, after /clear or /compact, when the user asks 'where was I?', wants to continue previous work, or resume after a break."
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
---

<objective>
You are starting a new session (or one that just got cleared/compacted) and
need to re-acquire context from the previous session's `/checkpoint` memo.
Find the most recent memo for the current project, summarise it in five
lines, and propose the first concrete action — usually whatever sits at the
top of the memo's "Open / next" section.

You are NOT re-doing the previous session's work. You are NOT running
commits, deploys, or destructive operations. You read the memo, surface it,
and wait for the user to confirm before doing anything that changes state.
</objective>

<other_skills_in_this_space>

`/resume` is the companion to `/checkpoint`. Pick the right resume skill
based on where the previous session stored its handoff:

- **`/resume`** (this skill) — reads
  `~/.claude/.../memory/project/session-checkpoint-*.md`. Use after a
  `/checkpoint` on the same machine.
- **`/gsd-resume-work`** — reads `.continue-here.md` and `STATE.md` in the
  project repo. Use in GSD projects (those with `.planning/`).
- **`/handoff`** doc on disk — if the user mentions a handoff at
  `$TMPDIR/handoff-*.md`, point them at that file directly; this skill
  does not look there.

If the project has `.planning/` or `STATE.md` and you do not have a strong
reason to override, stop and route the user to `/gsd-resume-work`.

</other_skills_in_this_space>

<process>

## 1. Locate the project memory folder

The auto-memory system prompt typically surfaces the path. Otherwise derive
it: replace `/` with `-` in the absolute working directory, prefix with `-`,
then build `$HOME/.claude/projects/<encoded>/memory/`.

If the folder does not exist or contains no `project/session-checkpoint-*.md`
files, stop and tell the user — `/resume` only makes sense when there is
a checkpoint to read. Suggest `/checkpoint` if they want to start the
discipline now.

## 2. Find the most recent checkpoint

```bash
ls -t "<memory_dir>/project/session-checkpoint-"*.md 2>/dev/null | head -5
```

Pick the most recent by mtime (top of the list). If two or more files were
modified within the last 24 hours, briefly list them by title (the
frontmatter `name:` field) so the user can pick if your top guess is wrong.

Skip files marked `[stale]` in `MEMORY.md` unless the user explicitly asked
to resume one — stale checkpoints point at branches that no longer exist.

## 3. Read the memo and summarise

Read the chosen file. Produce a five-line summary in this exact shape:

```
Resuming: <name field from frontmatter>
Branch:   <Branch line>  (run `git branch --show-current` to verify it still exists)
Done:     <one-line distilled from Done this session>
Open:     <first item from Open / next>
Hints:    <one line from Continuation hint for next Claude>
```

If the branch in the memo does not match the current branch (`git branch
--show-current`), flag it loudly — the user may have switched contexts.

If the memo is older than 7 days, say so. Old checkpoints often describe
state that has already drifted.

## 4. Propose the first concrete action

Look at "Open / next" in the memo. Translate the top item into a single
proposed first action with the exact file paths from the memo. Examples:

- "Read `frontend/src/features/admin/pages/enrollments/index.tsx`, then continue T-5.6 from the cursor at line 124."
- "Run the failing test in `tests/checkout.spec.ts` to confirm the red state, then continue the green step."
- "Open the PR draft saved at `Branch:` — commits are already pushed."

Do NOT run that action yet. Print it, then wait for the user to confirm
("go", "yes", "do it") before changing any state. If the action involves
git operations, commits, deletes, or pushes, ALWAYS wait for explicit
confirmation — even if the memo says "next: push the branch".

## 5. Surface uncommitted state

After proposing, quickly check `git status --short` and `git stash list`.
If there is uncommitted work or stashed work that the memo mentions,
mention it. If there is uncommitted work the memo does NOT mention, that
is suspicious — surface it as a question ("there's a dirty `src/api.ts`
that the previous checkpoint did not mention — should I look at it?").

## 6. Hand control back

Stop here. You have done your job: the user now has a 5-line context
recap, a proposed first action, and a flag on any mismatch between the
memo and the current working state. The next message from the user
tells you whether to proceed.

</process>

<style>

- Brief. Five-line summary, one proposed action, one optional warning.
  Not a wall of text — the user can read the memo themselves if they
  want more.
- Quote exact paths and SHAs from the memo. Do not paraphrase them.
- Never silently run the proposed action. Always wait for the user's go.

</style>

<output>

```
Resuming: <topic>
Branch:   <branch>
Done:     <one-line>
Open:     <one-line>
Hints:    <one-line>

Proposed first step: <concrete action with file paths>

(Optional) Heads-up: <branch mismatch, dirty tree, stale memo, etc.>

Ready when you are.
```

That's it — wait for the user's reply.

</output>
