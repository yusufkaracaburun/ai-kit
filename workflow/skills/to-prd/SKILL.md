---
name: to-prd
description: Turn the current conversation context into a PRD and publish it to the project issue tracker. Also supports Idea mode — when the user wants a short parking-lot capture ("defer this", "track this for later", "follow-up on …", "we'll do this in N") instead of a full PRD, produce an idea card (a one-line issue + roadmap entry). Use when user wants to create a PRD, defer a lead, or capture a follow-up.
model: fable
---

This skill takes the current conversation context and codebase understanding and produces either:

- a **full PRD** (default) — when the user wants to commit to building an epic and lock scope, or
- an **idea card** (Idea mode) — when the user wants to park a lead so future planning sessions can grab it without re-discovering the context.

Pick by intent: PRD = "this is happening, lock requirements before we start". Idea = "remember this, not decided or not now".

The issue tracker and triage label vocabulary should have been provided to you — run `/ai:setup` if not.

## Idea mode

Trigger when the user says:

- "defer this"
- "track this for later"
- "we'll do this in N"
- "follow-up on …"
- "open an issue + add to roadmap"
- `/ai:to-prd idea <one-line lead>`

Do **not** invoke Idea mode when the user wants the work done now — an idea is never executed as it is. A known fault is always a bug card, also when it waits in Backlog: use `bug.md` and type `Bug`, the rest of this mode stays the same. Also distinct from [`to-issues`](../to-issues/SKILL.md), which breaks ONE plan into N stories. Idea mode is ONE surfaced lead → ONE issue + ONE roadmap paragraph.

### Process (Idea mode)

#### 1. Read context

Pull from the conversation:

- The lead itself — one-line summary.
- Why it surfaced — what review, plan, or research turn produced it.
- Why-not-now — what blocks doing it in this session (scope, dependencies, decision pending).
- Related issues — issue numbers mentioned recently, or sibling roadmap entries.

If the lead is ambiguous, ask **one** clarifying question. Otherwise proceed.

#### 2. Detect the local environment

- `gh auth status --hostname github.com` — is GitHub CLI authenticated?
- `git config --get remote.origin.url` — does the repo have a remote?
- `test -f docs/roadmap.md` — does the roadmap file exist?
- `gh label list --limit 200 | grep -w "<label>"` — does the chosen label exist?

| Found | Behaviour |
| ----- | --------- |
| `gh` + remote + roadmap | Full flow: issue → roadmap entry → report |
| `gh` + remote, no roadmap | Issue only; warn that roadmap update was skipped |
| no `gh` / no remote, roadmap present | **Local-only mode**: append roadmap entry with `(no issue — gh unavailable)`, surface to user |
| nothing | Refuse — there's nowhere to capture; ask the user where to put it |

If the label does not exist, fall back to no label rather than failing — and tell the user which label was dropped. Default label: the one in the template's frontmatter, per [`triage/ISSUE-BODY.md`](../triage/ISSUE-BODY.md) (`bug` for a fault).

#### 3. Draft the issue body

Use `idea.md`, or `bug.md` for a known fault, per [`triage/ISSUE-BODY.md`](../triage/ISSUE-BODY.md). Keep it concrete and observable, and name the smallest plausible delivery, not the ideal one. Future-you needs to know if the blocker is still live before picking this up. Link any related ADR, skill or issue.

#### 4. Create the issue — no approval gate

Idea mode is light parking, not scope-lock. Skip the "Capture as drafted, edit, or abort?" approval step — produce issue + roadmap entry immediately. Per `feedback_followup_no_approval_gate` memory: deferred leads do not warrant a round of approval; users redirect after the fact if needed.

```bash
gh issue create \
  --title "<title>" \
  --label "<label>" \
  --body-file <path>
```

A `bug.md` card in a repo with epic templates also takes `--parent <epic>`, per [`triage/ISSUE-BODY.md`](../triage/ISSUE-BODY.md); an idea needs none.

Capture the returned issue number — needed for the roadmap pointer. Then set its type, Priority and board spot (type `Bug` when the lead is a fault, else `Task`; add `--priority` only when the user named one):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" <issue> --type Task
```

If `gh` returns non-zero, surface the exact error to the user; do not proceed to roadmap update with a missing issue ID.

#### 5. Append the roadmap entry

Open `docs/roadmap.md` and append a numbered paragraph to the **last `## What's next`** section. Use the next unused number — read the section, count entries, pick `<n+1>`. Reference the new issue as `(#N)`.

```markdown
N. **<lead, title cased>** (#<issue-number>) — <one-paragraph
   context: why deferred, what unblocks it, who owns it. End with a
   pointer to related ADR or sibling roadmap entry if any.>
```

If the agent cannot find a `## What's next` heading, **do not invent one** — surface to the user and ask where to place the entry.

#### 6. Ship + report

Run `review` on the staged `docs/roadmap.md` change, then hand the commit to one ship brief ([`triage/SHIP-BRIEF.md`](../triage/SHIP-BRIEF.md)), per the [git-hygiene rule](../../../standards/rules/git-hygiene.mini.md): paths `docs/roadmap.md`, deploy `none`, branch, PR and merge as the project's own git policy says. One commit:

```
chore(idea): capture #<N> in roadmap

<one-line context — what prompted the idea>
```

Single-line report, once the ship brief reports the commit:

```
Captured: <issue URL> + docs/roadmap.md § What's next entry N.
```

### Decisions baked in (Idea mode)

| Choice | Default | Why |
| ------ | ------- | --- |
| Label | the template's own | One source for the label. Override via `--label`. |
| Roadmap section | last `## What's next` | New work converges there; topic-matching is fragile. |
| Local-only mode | append roadmap entry, no issue | Better to capture *something* than refuse. Surfaces clearly. |
| Approval gate | **none** | An idea is light parking; users redirect after the fact. |

### What Idea mode does NOT do

- Does **not** start the work — that's the next `tdd` / `to-issues` cycle.
- Does **not** close other issues, even if the new one supersedes them.
- Does **not** edit `CHANGELOG.md` — an idea is forward-looking, not historical.

## PRD mode (default)

When the user wants a full spec, not a parking-lot capture.

### Process

1. **Grill-first gate.** Apply [`grill-first.mini.md`](../../../standards/rules/grill-first.mini.md) before drafting anything — route to `grill-with-docs` (it creates `CONTEXT.md` when missing), and wait for answers. Skip only if the open questions were already answered in this turn or the user said "go" / "skip grill".

2. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the PRD, and respect any ADRs in the area you're touching.

3. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

4. Write the PRD using the template below, then publish it to the project issue tracker, posted as [`triage/ISSUE-BODY.md`](../triage/ISSUE-BODY.md) says. A PRD is the worked-out text of an epic: the headings of `epic.md` come first (or the template ISSUE-BODY picks when the repo has no `epic.md`), in the repo's language, then the extras in the template below. Its boxes follow [provable checkboxes](../triage/ISSUE-BODY.md#provable-checkboxes). Apply the `ready-for-agent` triage label — no need for additional triage — and post the `## Agent Brief` comment with the label, in the order [`triage/AGENT-BRIEF.md`](../triage/AGENT-BRIEF.md) § Posting gives. The brief distils the PRD into that template's shape, with the acceptance criteria inline. Then run `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" <issue> --type Epic`, adding `--priority` when the grill set one.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <capability>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the epic.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- The seams the tests sit at: prefer existing seams, and the highest one that reaches the behavior; fewer seams is better (idea from mattpocock/skills abeeaf9)
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Further Notes

Any further notes about the epic.

</prd-template>
