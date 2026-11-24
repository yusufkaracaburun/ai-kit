---
name: Story
about: One deliverable piece of work, part of an epic
title: ""
labels: [enhancement]
---

## Triage

- **Epic:** epic/<name> / none
- **Area:** area/<name> (pick one or more)
- **Depends on:** #N / external (<what>) / none
- **Blocks:** #N / none
- **Estimate:** <estimated diff in lines>
- **Ready to start:** YES / NO — missing: <what is missing>

## Scope

<What are we building, in 1-3 sentences.>

<!-- Optional: subtasks as `- [ ]` lines -->

## Acceptance criteria

- [ ] <Measurable criterion> (proof: <command, test, screenshot or measurement>)
- [ ] <Measurable criterion> (proof: <command, test, screenshot or measurement>)

## Definition of Ready (before "In Progress")

- [ ] Priority field set (or a P label if the repo has no field) + Area label set + Epic label, or none (proof: fields and labels on the card)
- [ ] Independent: every blocker is under Depends on, or "none" (proof: the Depends on line)
- [ ] Small: fits one PR (proof: estimate on the card ≤ 400 lines, or a reason)
- [ ] Testable: every acceptance criterion names its proof (proof: the criteria above)
- [ ] Nothing is missing to start (proof: Ready to start says YES)

## Definition of Done (before close)

- [ ] Every acceptance criterion ticked (proof: commit, test run or screenshot per criterion)
- [ ] Tests green, or the result measured (proof: suite and result, or the measurement)
- [ ] Docs match the domain change, or there is none (proof: commit, or "no domain change")
- [ ] Review APPROVE (proof: report as a comment on the card or PR, or no diff)
