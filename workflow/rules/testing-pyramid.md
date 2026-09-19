---
paths: ["**/tests/**", "**/test/**", "**/__tests__/**", "**/*.test.*", "**/*.spec.*", "**/*_test.*"]
---
<!-- ai-kit global rule (ADR-0015): Test mix discipline — many fast unit tests, fewer integration tests, very few E2E tests -->
<!-- Source: standards/rules/testing-pyramid.mini.md — re-stamp with bin/sync-plugin-rules.sh -->


# Testing pyramid

Keep the test mix shaped like a pyramid — wide base of fast tests, narrow tip
of slow ones. Inverted pyramids (mostly E2E) are slow, flaky, and produce
non-actionable failures.

## Target ratios

- **Unit / fast integration** (≥ 70%) — pure functions, single-class behavior,
  in-memory boundaries. Run in < 5 ms each.
- **Integration / service** (≤ 25%) — exercise real DB, real HTTP, real queue
  inside one service boundary. Run in < 500 ms each.
- **E2E / system** (≤ 5%) — full stack through the UI or public API. Reserved
  for critical user journeys (checkout, signup, payment). Run in seconds.

## Hard rules

- Every bug fix lands with a test that would have caught it. No exceptions.
- A failing test must point at one defect, not "something somewhere broke".
- E2E tests cover **happy paths only**. Edge cases live in unit/integration.
- Flaky tests get fixed or deleted in the same PR they're discovered — never
  retried-3-times-in-CI.
- Test names describe **behavior**, not implementation
  (`checkout_with_expired_card_fails`, not `test_charge_method_returns_false`).

## Anti-patterns

- "Test pyramid inverted" — lots of E2E, few units. Symptom: CI takes > 10 min
  and "fix the flake" is a recurring task.
- Mocking internal collaborators in unit tests — couples tests to
  implementation, breaks on refactor without behavior change.
- Snapshot tests as the primary verification — they assert shape, not behavior.

## See also

- `tdd` skill — red/green/refactor loop.
- `legacy-code.mini.md` — characterisation tests when
  pyramid is broken in inherited code.
