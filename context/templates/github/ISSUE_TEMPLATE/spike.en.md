---
name: Spike / research
about: Time-boxed research or platform decision that produces an ADR
title: "Spike: "
labels: [enhancement]
---

## Triage

- **Priority:** P0-critical / P1-high / P2-medium / P3-low
- **Epic:** epic/<name>
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

- [ ] Priority + Epic + Area labels set
- [ ] Time-box explicit
- [ ] Goal + decision list concrete (no "research X" without scope)

## Definition of Done (before close)

- [ ] ADR written in `docs/adr/NNNN-<slug>.md` with decision + rationale + alternatives-considered
- [ ] Time-box respected (otherwise: stop + re-scope)
- [ ] Downstream issues created or existing issues updated with chosen-stack-reference
- [ ] Any proof-of-concept cleaned up (not merged to master unless explicitly decided)
