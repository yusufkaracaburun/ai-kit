---
id: recurring-tasks
skill: to-prd
required_headings:
  - "## Problem Statement"
  - "## Solution"
  - "## User Stories"
  - "## Implementation Decisions"
  - "## Testing Decisions"
required_keywords:
  - "ready-for-agent"
  - "user"
  - "anti-goal"
forbidden_keywords:
  - "TODO"
  - "FIXME"
  - "[fill in]"
  - "[placeholder]"
min_lines: 50
max_lines: 400
---

# Hand-written golden output for `to-prd` / `recurring-tasks`

This file represents an *ideal* `to-prd` response for the `recurring-tasks` fixture.
It is used as a regression baseline: a real model response should hit the same
structural and semantic checks declared in the frontmatter above.

The output below is what a model should produce after running the `to-prd` skill
on the fixture prompt, with the surrounding conversation already having gathered
basic context about the project (it's a project-management tool, users have asked
for recurring tasks for months).

---

## Problem Statement

Users who manage repeating work (weekly reports, monthly billing checks, daily
stand-ups) currently re-create the same task by hand every cycle. The repeated
manual entry is error-prone (people forget, or fill in inconsistent metadata)
and consumes time that should go to the actual work.

The primary user affected is the **individual contributor** who owns one or more
recurring obligations. A secondary affected user is the **team lead** who tracks
whether those recurring obligations were completed each cycle.

## Solution

Allow a task to be marked "recurring" with a repeat rule (daily / weekly /
monthly / custom cron-like cadence). The system materialises the next instance
automatically when the previous instance is closed (or on a schedule, whichever
the user prefers). Each materialised instance is a normal task, independently
editable, but inherits defaults from the template.

Anti-goals for v1:

- No support for arbitrary calendar rules (RRULE-style exceptions, holiday
  skips, business-day offsets) — punt to v2.
- No team-level templates (only the assignee can create a recurrence).
- No backfill of historical instances when a recurrence is added retroactively.

## User Stories

1. As an individual contributor, I want to mark a task as recurring on a weekly
   cadence, so that I do not have to recreate it every Monday.
2. As an individual contributor, I want to choose between "create next on
   completion" and "create next on schedule", so that recurring tasks match how
   I actually work.
3. As an individual contributor, I want to edit a single instance without
   affecting future instances, so that I can adjust the scope of one cycle
   without breaking the pattern.
4. As an individual contributor, I want to edit the recurrence template, so
   that all future instances pick up the new defaults.
5. As an individual contributor, I want to pause a recurrence, so that I can
   stop a series temporarily without losing the configuration.
6. As an individual contributor, I want to end a recurrence, so that I can
   close out a series that no longer applies.
7. As a team lead, I want to see which recurring tasks an assignee owns, so
   that I can understand their ongoing commitments.

## Implementation Decisions

- A new `recurrence` module owns the repeat-rule definition and the
  materialisation logic. The interface exposes `schedule`, `pause`, `resume`,
  `end`, and a `next_instance_due_at(now)` query.
- Tasks gain an optional `recurrence_id` pointer; the existing task model is
  otherwise unchanged. No schema changes to existing rows.
- Materialisation runs on a background scheduler tick (per project's existing
  job runner — derive from `docs/agents/dev-environment.md` rather than assume
  Sidekiq/Celery/etc.).
- The repeat-rule vocabulary covers: daily, weekly (by weekday list), monthly
  (by day-of-month), and custom cadence in days. Cron syntax is **not**
  exposed in the UI in v1.
- API contract: `POST /tasks` accepts a `recurrence` object; `PATCH
  /recurrences/:id` updates the template; `DELETE /recurrences/:id` ends the
  series (does not delete past instances).

## Testing Decisions

- Unit-test the `recurrence` module in isolation: `next_instance_due_at`
  against a wide grid of cadences and reference dates.
- Integration tests around materialisation: given a series and a "now" cursor,
  the correct number of instances exist with correct due dates.
- End-to-end test for the primary flow: create a weekly recurring task, close
  the first instance, observe the second instance materialise with the
  expected metadata.

## Rollout

- Behind a feature flag (`feature.recurring_tasks`) for the first release.
- Default off for existing users; surface a banner in the task-create modal
  for opt-in.
- Monitor: `recurrences.created`, `recurrences.materialised`,
  `recurrences.paused`, `recurrences.ended` counters; alert on
  materialisation lag > 5 minutes.

---

*Published to the project issue tracker with the `ready-for-agent` triage label.
Linked to upstream issues that requested this functionality.*
