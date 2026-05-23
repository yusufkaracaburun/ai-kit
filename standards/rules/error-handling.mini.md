---
name: error-handling
description: Fail fast at boundaries, trust internal code, never swallow errors
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Error handling

The two failure modes that hurt most: errors that crash production when they
should have been caught at the boundary, and errors that get swallowed so
nobody knows the system is broken. This rule prevents both.

## Where to validate

- **At system boundaries** (HTTP handlers, queue consumers, CLI args, file
  parsers) — validate aggressively. Reject early with a clear message.
- **Inside internal code** — trust the types and the contract. No defensive
  `if (input == null)` everywhere; that's noise that hides real bugs.

## When to throw vs return

- **Throw / panic** for *unexpected* conditions — broken invariants, programmer
  errors, things that should never happen.
- **Return result/error type** for *expected* failure modes — network timeout,
  user input invalid, resource not found.
- Don't use exceptions for control flow.

## Never do this

- **Swallow errors silently.** `try { ... } catch {}` without re-throw, log,
  or business decision = future incident.
- **Catch the broadest exception** (`except Exception:`, `catch (Throwable)`)
  unless you also log + re-throw or convert to a domain error.
- **Re-throw with lost context.** Wrap, don't replace — keep the original
  stack/cause.
- **Crash the worker on a single bad message** — isolate per-item failures
  in batch / queue processors.

## At the boundary

- HTTP errors return RFC 7807 (Problem Details) or your project's documented
  error envelope — same shape every time.
- Validation errors are structured (field → message), not a single string.
- 5xx responses are bugs to fix; 4xx are client errors with actionable messages.

## See also

- [`observability.mini.md`](./observability.mini.md) — log levels for errors.
- [`api-design.mini.md`](./api-design.mini.md) — error response shape.
