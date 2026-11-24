---
name: Spike / research
about: Time-boxed research or proof of concept that produces an ADR
title: "Spike: "
labels: [enhancement]
---

## Triage

- **Epic:** epic/<name> / none
- **Area:** area/<name>
- **Depends on:** #N / external / none
- **Blocks:** #N (which issues does this spike unblock?)
- **Ready to start:** YES / NO — missing: <what is missing>
- **Time-box:** <hours or days — required for spikes>

## Goal

<What decision or insight does this spike produce?>

## Decisions this spike produces

1. <Question 1>
2. <Question 2>
3. <Question 3>

## Definition of Ready (before "In Progress")

- [ ] Priority field set (or a P label if the repo has no field) + Area label set + Epic label, or none (proof: fields and labels on the card)
- [ ] Time-box set (proof: the Time-box line)
- [ ] Every decision is a question with a scope (proof: the list above)

## Definition of Done (before close)

- [ ] Decision + rationale + alternatives recorded (proof: `docs/adr/NNNN-<slug>.md`, commit)
- [ ] Time spent within the time-box, else stopped and re-scoped (proof: comment on the card with the time spent)
- [ ] Downstream issues created or updated, or there are none (proof: links, or "none")
- [ ] Proof of concept cleaned up, or there is none (proof: commit or deleted branch, or "none")
