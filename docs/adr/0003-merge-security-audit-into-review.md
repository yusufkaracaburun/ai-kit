# ADR-0003: Merge `security-audit` into `aikit-review`

## Status

Accepted (v0.2.0; documented retrospectively in v1.1.0)

## Context

v0.1 shipped `security-audit` as a separate skill alongside `aikit-review`. In practice they were invoked together 80% of the time, and `security-audit` mostly re-implemented `aikit-review`'s diff-walking logic against a security-specific rubric. Two skills, one workflow, lots of duplication.

When users were asked which they preferred to invoke, the answer was *neither* — they wanted "is this safe to land?" as one question.

## Decision

Fold the security-audit rubric into `aikit-review` as a **deep pass**:

- `aikit-review` runs the standard pre-merge check (correctness, tests, alignment with CONTEXT.md).
- When the diff touches surface-area that matters (auth, parsers, file I/O, network), the security rubric activates and is reported alongside the standard findings.
- The skill ships a single output that says "ready to land" or "not yet, here's why".

`security-audit` was removed as a distinct skill.

## Consequences

**Positive**

- One mental model: pre-merge = `aikit-review`.
- The security pass is no longer optional; touching risky surface area triggers it automatically.
- One less skill name to remember.

**Negative**

- A user who wants *only* a security audit (e.g. of a stale branch they're not about to merge) has to invoke `aikit-review` and ignore the non-security findings. Rare enough to accept.

**Follow-ups**

- If a deep-security workflow re-emerges (e.g. pen-test prep, full STRIDE walkthrough), it'd be a new skill — `security-deep` — not a revival of `security-audit`. The decision to merge was about overlap, not about devaluing security.
