---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker as stories, cut as tracer-bullet vertical slices. Use when user wants to convert a plan into issues, create stories or implementation tickets, or break down work into issues.
model: fable
---

# To Issues

Break a plan into independently-grabbable stories, cut as vertical slices (tracer bullets). A vertical slice is published as a story.

**Not this skill** — use [`to-prd`](../to-prd/SKILL.md) in Idea mode when the user wants to *park* a single surfaced lead (one issue + one roadmap paragraph). `to-issues` is for shattering an already-planned chunk of work into N stories ready to execute. Idea mode pushes work OUT of now; `to-issues` decomposes work INTO actionable stories.

The triage label vocabulary lives in `docs/agents/triage-labels.md`, written by `/ai:setup`; run `/ai:setup` if it is missing.

Issue titles, branch names, and commit messages follow the [git-hygiene rule](../../../standards/rules/git-hygiene.mini.md). Default branch prefix per type: AFK + story → `feat/`, AFK + bug → `fix/`, HITL → ask first.

## Second-dev cold-pickup rule

Every issue this skill produces must contain enough context that a **second
dev** — teammate, AFK agent, or returning maintainer — who has never seen
the conversation can act on it cold. Each issue gets a parent reference, a
behavioral description of the story, inline
[provable](../triage/ISSUE-BODY.md#provable-checkboxes) acceptance criteria, and explicit blockers. The `## Agent Brief`
comment is the contract surface and the issue body its context; conversation
context is neither.

Rationale: the defaults assume ≥2 devs (one writer, one reviewer). The repo template plus the extra headings in step 5 carry this structure — never
emit an issue that drops acceptance criteria or the parent pointer. If a
story cannot be specified cold from current context, keep grilling before
publishing.

## Run mode

- **Claude Code:** for the codebase exploration in step 2, delegate to the `explore` subagent via the Task tool with `subagent_type=ai:explore` — ask it to map the area the plan touches and the current state of the code, and return a ≤300-line summary. Drafting stories, quizzing the user, and publishing issues stay in this context.
- **Hosts without subagents:** explore inline, filtered per [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it from the issue tracker and read its full body and comments.

### 1.5. Grill-first gate

Before drafting stories, apply [`grill-first.mini.md`](../../../standards/rules/grill-first.mini.md). Issue bodies and PRDs look complete but are almost always under-specified — scope split, detection logic, override patterns, and bundle-vs-defer decisions are usually implicit. Route to `grill-with-docs` (it creates `CONTEXT.md` when missing) and wait for answers before drafting stories. Skip only when the user has answered the open questions in the same turn or said "go" / "skip grill".

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code — see **Run mode** for delegating this to `explore`. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft the stories

Break the plan into **tracer bullet** stories. Each story is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Stories may be 'HITL' or 'AFK'. HITL stories require human interaction, such as an architectural decision or a design review. AFK stories can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each story delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed story is demoable or verifiable on its own
- Prefer many thin stories over few thick ones
- A prefactor that makes the change easy lands first, as its own story
</vertical-slice-rules>

**Sweeping mechanical changes get a parallel change instead.** Moving a shared helper to a new module or changing a widely used function's argument order touches so many files that no single story can ship green. Split it in three: one issue adds the new form next to the old one; then one issue per group of callers (per package or directory) switches them over, each depending on the first; a last issue removes the old form once every switch-over issue is done. Ideas from mattpocock/skills abeeaf9.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each story, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other stories (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any stories be merged or split further?
- Are the correct stories marked as HITL and AFK?
- Do these stories merge into main one at a time, or into an `epic/<name>`
  integration branch first?

The last question is not optional and has no safe default. It sets the PR base
of every story, and the answer only stays cheap while the stories are still on
paper: once a story's commits are already in a branch, GitHub refuses to open the
PR at all (`422 There are no new commits between base branch and head branch`),
and a PR that was never opened has no base to edit later. It also decides whether
the dependency chain below means "merged to main" or "merged to the epic branch"
— the blockers read differently under each model. See the epic section of the
[git-hygiene rule](../../../standards/rules/git-hygiene.mini.md).

Iterate until the user approves the breakdown.

### 5. Publish the issues to the issue tracker

For each approved story, publish a new issue to the issue tracker. Each story follows [`triage/ISSUE-BODY.md`](../triage/ISSUE-BODY.md): `story.md`, or `bug.md` when it fixes a fault. `gh issue create --parent <epic>` hangs it under its epic. These issues are considered ready for AFK agents, so publish them with the correct triage label unless instructed otherwise, and post the `## Agent Brief` comment with the label, in the order [`triage/AGENT-BRIEF.md`](../triage/AGENT-BRIEF.md) § Posting gives. The brief restates the story in that template's shape: Rule changed, its acceptance criteria inline, Out of scope, the test command and the Decisions in force.

Publish issues in dependency order (blockers first) so you can reference real issue identifiers in the template's "Depends on" field; a template without that field gets a `**Depends on:** #N` line above its first heading.

After each issue is created, give it its type, Priority and board spot. Type `Story`, or `Bug` when it fixes a fault; `--parent` is the PRD or epic issue, omitted when there is none. The script never fails the run; pass its stderr lines on to the user.

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" <issue> --type Story --parent <parent-issue>
```

Write the estimated diff in lines on the story's Estimate line; above 400, split it or give the reason there. Describe the story's end-to-end behavior, not layer by layer. Avoid specific file paths or code snippets: they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline the decision-rich part and note that it came from a prototype.

Then add these headings after the template's own, each as `##`:

- **Parent**: a reference to the parent issue. Omit when the source was not an issue.
- **Branch and PR base**: branch `<prefix>/<area>-<short-desc>`; open the PR against `<base>` (`main`, or the epic's `epic/<name>` branch). State the base explicitly even when it is main: a second dev picking this up cold cannot infer it from the issue.

Do NOT close or modify any parent issue.
