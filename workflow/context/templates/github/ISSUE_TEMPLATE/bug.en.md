---
name: Bug
about: Something does not work as it should
title: ""
labels: [bug]
---

## Steps

1. <Step 1>
2. <Step 2>

## Expected

<What should have happened.>

## Actual

<What happens, with the literal error message.>

<!-- Optional: screenshot or log -->

## Where

- **Page:** <URL or screen>
- **Environment:** <production / staging / local, browser or device>
- **Version:** <release or commit>

## Acceptance criteria

- [ ] <Measurable criterion> (proof: <command, test, screenshot or measurement>)
- [ ] Regression test that fails without the fix (proof: name of the test)

## Definition of Done (before close)

- [ ] Regression test fails before the fix and passes after it (proof: both test runs)
- [ ] Cause found (proof: note on the card)
- [ ] Every acceptance criterion ticked (proof: commit, test run or screenshot per criterion)
- [ ] Review APPROVE (proof: report as a comment on the card or PR, or no diff)
