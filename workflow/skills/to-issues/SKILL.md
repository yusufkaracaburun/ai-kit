---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices. Use when user wants to convert a plan into issues, create implementation tickets, or break down work into issues.
---

# To Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets).

**Not this skill** — use [`to-prd`](../to-prd/SKILL.md) in defer mode when the user wants to *park* a single surfaced lead (one issue + one roadmap paragraph). `to-issues` is for shattering an already-planned chunk of work into N tickets ready to execute. Defer mode pushes work OUT of now; `to-issues` decomposes work INTO actionable slices.

The triage label vocabulary lives in `docs/agents/triage-labels.md`, written by `/ai:setup`; run `/ai:setup` if it is missing.

Issue titles, branch names, and commit messages follow the [git-hygiene rule](../../../standards/rules/git-hygiene.mini.md). Default branch prefix per type: AFK + feature → `feat/`, AFK + bug → `fix/`, HITL → ask first.

## Second-dev cold-pickup rule

Every issue this skill produces must contain enough context that a **second
dev** — teammate, AFK agent, or returning maintainer — who has never seen
the conversation can act on it cold. Each issue gets a parent reference, a
behavioral *what to build* description, inline machine-checkable
acceptance criteria, and an explicit *blocked by* list. The issue body is
the contract surface; conversation context is not.

Rationale: ai-kit defaults assume ≥2 devs (one writer, one reviewer), per
ai-kit issue #52. The to-issues template enforces this structure — never
emit an issue that drops acceptance criteria or the parent pointer. If a
slice cannot be specified cold from current context, keep grilling before
publishing.

## Run mode

- **Claude Code:** for the codebase exploration in step 2, delegate to the `explore` subagent via the Task tool with `subagent_type=explore` — ask it to map the area the plan touches and the current state of the code, and return a ≤300-line summary. Drafting slices, quizzing the user, and publishing issues stay in this context.
- **Hosts without subagents:** explore inline, filtered per [`context-discipline.mini.md`](../../../standards/rules/context-discipline.mini.md).

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it from the issue tracker and read its full body and comments.

### 1.5. Grill-first gate

Before drafting slices, apply [`grill-first.mini.md`](../../../standards/rules/grill-first.mini.md). Issue bodies and PRDs look complete but are almost always under-specified — scope split, detection logic, override patterns, and bundle-vs-defer decisions are usually implicit. Route to `grill-with-docs` (if domain docs exist) or `grill-me` and wait for answers before drafting slices. Skip only when the user has answered the open questions in the same turn or said "go" / "skip grill".

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code — see **Run mode** for delegating this to `explore`. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?
- Do these slices merge into main one at a time, or is this an **epic** whose
  slices merge into an `epic/<name>` integration branch first?

The last question is not optional and has no safe default. It sets the PR base
of every slice, and the answer only stays cheap while the slices are still on
paper: once a slice's commits are already in a branch, GitHub refuses to open the
PR at all (`422 There are no new commits between base branch and head branch`),
and a PR that was never opened has no base to edit later. It also decides whether
the dependency chain below means "merged to main" or "merged to the epic branch"
— the blockers read differently under each model. See the epic section of the
[git-hygiene rule](../../../standards/rules/git-hygiene.mini.md).

Iterate until the user approves the breakdown.

### 5. Publish the issues to the issue tracker

For each approved slice, publish a new issue to the issue tracker. Use the issue body template below. These issues are considered ready for AFK agents, so publish them with the correct triage label unless instructed otherwise.

Publish issues in dependency order (blockers first) so you can reference real issue identifiers in the "Blocked by" field.

<issue-template>
## Parent

A reference to the parent issue on the issue tracker (if the source was an existing issue, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Branch and PR base

Branch `<prefix>/<area>-<short-desc>`; open the PR against `<base>` (`main`, or
the epic's `epic/<name>` branch). State the base explicitly even when it is
main — a second dev picking this up cold cannot infer it from the issue.

## Blocked by

- A reference to the blocking ticket (if any)

Or "None - can start immediately" if no blockers.

</issue-template>

Do NOT close or modify any parent issue.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" to-issues start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" to-issues done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

