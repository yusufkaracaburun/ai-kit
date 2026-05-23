---
name: followup
description: One-shot defer capture — open a GitHub issue in house style and append a roadmap entry referencing it. Use when a deferred lead surfaces during planning, review, or research and the user says "defer this", "track this for later", "we'll do this in N", "open an issue + add to roadmap", or invokes `/ai:followup`.
---

# Followup

Capture a deferred lead as **both** a GitHub issue and a `docs/roadmap.md` entry in one pass, so future planning sessions can grab it without re-discovering the context.

This skill replaces the two-step "open an issue, then add a roadmap paragraph" bookkeeping that used to happen ad-hoc — and it ships cross-project via the ai-kit plugin, so the default applies everywhere ai-kit is installed (not just one repo's memory file).

## When to invoke

Trigger phrases:

- "defer this"
- "track this for later"
- "we'll do this in N"
- "open an issue + add to roadmap"
- "follow-up on …"
- `/ai:followup <one-line lead>`

Do **not** invoke when the user is asking to fix the thing now — `followup` is for deferral, not execution.

**Not this skill** — use [`to-issues`](../to-issues/SKILL.md) when the user wants to *break down* an already-planned chunk of work into N independently-grabbable tracer-bullet tickets. `followup` is for ONE surfaced lead → ONE issue + ONE roadmap paragraph. `to-issues` is for ONE plan → N issues.

## Inputs

- **Lead** (required): one-line summary of the deferred work. From the user's prompt or the most recent agent turn.
- **Context** (optional): conversation context the agent already has — what prompted the lead, the verdict source (e.g. a `/should-i-use` outcome), related issues, the roadmap section it belongs under.
- **Label** (optional, default `enhancement`): GitHub label. Caller may pass `--label <name>`. Skill checks the label exists in the repo before applying.

## Process

### 1. Read context

Pull what's already in the conversation:

- The lead itself — the one-line summary.
- Why it surfaced — what review, plan, or research turn produced it.
- Why-not-now — what blocks doing it in this session (scope, dependencies, decision pending).
- Related issues — issue numbers mentioned recently, or sibling roadmap entries.

If the lead is ambiguous, ask **one** clarifying question. Otherwise proceed.

### 2. Detect the local environment

Run quick checks before mutating anything:

- `gh auth status` — is GitHub CLI authenticated?
- `git config --get remote.origin.url` — does the repo have a remote?
- `test -f docs/roadmap.md` — does the roadmap file exist?
- `gh label list --limit 200 | grep -w "<label>"` — does the chosen label exist?

Branch on what's available:

| Found | Behaviour |
| ----- | --------- |
| `gh` + remote + roadmap | Full flow: issue → roadmap entry → report |
| `gh` + remote, no roadmap | Issue only; warn that roadmap update was skipped |
| no `gh` / no remote, roadmap present | **Local-only mode**: append roadmap entry with `(no issue — gh unavailable)`, surface to user |
| nothing | Refuse — there's nowhere to capture; ask the user where to put it |

If the label does not exist, fall back to **no label** rather than failing — and tell the user which label was dropped.

### 3. Draft the issue body

Follow the house style — look at recent issues for shape (e.g. `gh issue view 14`, `gh issue view 15`, `gh issue view 16`). Use this template:

```markdown
## Pain

What hurts today, in 2-4 lines. Concrete and observable — not "code feels off".

## Proposed delivery

The shape of the fix. New primitive? Edit existing one? Cross-link to any
related ADR or skill. Surface the smallest plausible delivery, not the
ideal one — leave room for the eventual planner to refine.

## Why-not (now)

Why this is being deferred — scope, dependency, decision pending, owner
absent. One paragraph. Future-you needs to know if the blocker is still
live before picking this up.

## Roadmap pointer

`docs/roadmap.md` § <Section> — added <date>.
```

### 4. Show the draft, ask once

Before mutating anything, present:

- Proposed title (the lead, lightly polished — no period, sentence case)
- Proposed label
- Issue body draft
- Target roadmap section (default: last `## What's next`)
- Proposed roadmap paragraph (3-6 lines, refers to the issue by `(#N)` once created)

Ask: **"Capture as drafted, edit, or abort?"** Iterate until the user approves.

### 5. Create the issue

```bash
gh issue create \
  --title "<title>" \
  --label "<label>" \
  --body "<body>"
```

Capture the returned issue number — needed for the roadmap pointer.

If `gh` returns non-zero, surface the exact error to the user; do not proceed to roadmap update with a missing issue ID.

### 6. Append the roadmap entry

Open `docs/roadmap.md` and append a numbered paragraph to the **last `## What's next`** section. Use the next unused number — read the section, count entries, pick `<n+1>`. Reference the new issue as `(#N)`.

Sketch:

```markdown
N. **<lead, title cased>** (#<issue-number>) — <one-paragraph
   context: why deferred, what unblocks it, who owns it. End with a
   pointer to related ADR or sibling roadmap entry if any.>
```

If the agent cannot find a `## What's next` heading, **do not invent one** — surface to the user and ask where to place the entry.

### 7. Commit

Per [git-hygiene rule](../../../standards/rules/git-hygiene.mini.md). One commit, conventional message:

```
chore(followup): capture #<N> in roadmap

<one-line context — what prompted the deferral>
```

Commit directly to `master` (the ai-kit repo policy — see [feedback_no_pr_ceremony](file)). For other repos following ai-kit conventions, branch only if the repo's `git-hygiene` says so.

### 8. Report

Single line back to the user:

```
Captured: <issue URL> + docs/roadmap.md § What's next entry N.
```

## Decisions baked in

| Choice | Default | Why |
| ------ | ------- | --- |
| Label | `enhancement` | Matches existing issue labels (#14, #15, #16). Override via `--label`. |
| Roadmap section | last `## What's next` | New work converges there; topic-matching is fragile. |
| Local-only mode | append roadmap entry, no issue | Better to capture *something* than refuse. Surfaces clearly. |
| Asking before mutating | always | Issue + roadmap are durable artifacts; one round of approval is cheap. |

## What this skill does NOT do

- Does **not** start the work — that's the next `tdd` / `to-issues` cycle.
- Does **not** close other issues, even if the new one supersedes them — call that out in the body so the user can do it explicitly.
- Does **not** edit `CHANGELOG.md` — defer is forward-looking, not historical.
- Does **not** auto-detect "deferred" language from earlier turns — only acts when the user asks.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" followup start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" followup done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
