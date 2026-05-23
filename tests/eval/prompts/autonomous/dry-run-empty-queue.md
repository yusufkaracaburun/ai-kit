---
id: dry-run-empty-queue
skill: autonomous
expects:
  - defaults to `dry-run` mode when invoked without arguments
  - reads `.ai-kit/autonomous/progress.txt` first to detect an abandoned prior iteration and stops if one is found
  - queries `gh issue list --label ready-for-agent` to pick the oldest issue
  - writes `exit-empty` to `progress.txt` and exits cleanly when the queue is empty
  - does NOT create a branch, run TDD, open a PR, or invoke `tdd` / `review` / `ship` in `dry-run`
  - does NOT call `ScheduleWakeup` or recurse — pairing with `/loop` is the scheduler's job
  - in `one` or `drain` mode: fails fast on a dirty working tree before `git switch -c agent/issue-<n>-<slug>`
  - exits via a `exit-gate brief-thin` log line when the Agent Brief is missing or has no acceptance criteria
  - never auto-merges — always opens a PR and lets the project's merge policy decide
  - surfaces spike status (links the issue + `docs/spikes/ai:autonomous-ralph.md`) before any destructive step
---

# Prompt

Run `/ai:autonomous` against this repo. The `ready-for-agent` queue is
empty right now — I just want to see what the skill would do without it
touching anything.

Walk me through the state it reads, what it would pick if the queue were
non-empty, and how it exits when the queue is empty.
