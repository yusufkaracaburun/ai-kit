## Summary

<!-- 1-3 bullets: what changes and why. Reference the issue if applicable. -->

## Type

- [ ] feat — new capability
- [ ] fix — bug or regression
- [ ] docs — docs/comments only
- [ ] refactor — no behaviour change
- [ ] chore — tooling/CI/release plumbing

## Checklist

- [ ] `./tests/bin/run-tests.sh` passes locally
- [ ] If touched any SKILL.md: `./tests/bin/eval-structure.sh` passes
- [ ] If touched any `bin/*.sh`: `shellcheck` clean
- [ ] CHANGELOG.md updated
- [ ] No secrets, no absolute user paths, no `.DS_Store` committed

## Verification

<!-- What did you run / observe to convince yourself this works? -->

## Out of scope

<!-- Things this PR deliberately does NOT do, so reviewers don't ask. -->
