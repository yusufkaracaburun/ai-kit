---
name: code-audit
description: Whole-codebase architecture-quality audit checklist — 9 dimensions (patterns, SOLID, DRY, YAGNI, naming+comment-drift, coupling, layering, error-handling, type-safety)
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# OBEY Code-Audit Dimensions

## When to use

Use when scanning an existing codebase (not a diff) for architecture-quality issues — invoked by `/ai:audit-architecture`, or directly when the user asks "review the whole codebase", "find tech-debt", "where are the smells", "audit for SOLID/DRY violations". Stack-agnostic. Per-stack tuning layered on top.

Not for: pre-merge diff review (use `/ai:review`), deepening-opportunity hunts (use `/ai:improve-codebase-architecture`), or fixing — this rule is the **dimensions catalog**, fixing is a separate step.

## Primary bias to correct

Audits drift into either pedantry (every style nit flagged) or vibes ("looks fine"). The dimensions below force coverage; severity tags force triage.

## The 9 dimensions

Every finding belongs to exactly one dimension. If a finding doesn't fit, it isn't audit-scope — file it as a separate concern.

**Out of scope** for `audit-architecture` (cross-ref other primitives):

- Security → use `/ai:review` security-deep-pass or `/security-review`.
- Performance / runtime profiling → separate audit discipline; out of this skill's scope.
- Pre-merge diff review → use `/ai:review`.
- Deepening / refactor-candidate hunts → use `/ai:improve-codebase-architecture`.

**Testability** is a cross-cutting lens, not a dimension — testability problems surface as SOLID-DIP violations (#2), coupling smells (#6), or hidden temporal coupling (#6). Don't add a 10th bucket; tag the underlying dimension.

### 1. Design patterns

- Patterns used where they earn their keep, not sprinkled by reflex (Repository/Service/Policy/Factory/Strategy/Observer/etc.).
- Anti-pattern: framework-idiomatic patterns reimplemented from scratch (custom Service-locator next to a working DI container; hand-rolled Repository over an ORM that already provides it).
- Anti-pattern: pattern-name in a class that doesn't implement the pattern (`FooFactory` that returns one hard-coded type).

### 2. SOLID violations

- **S**ingle-responsibility: classes/modules that change for >1 reason. Look for "and" in the class name or docstring.
- **O**pen/closed: switch-on-type ladders that grow on every new variant.
- **L**iskov: subclass that throws on parent methods, narrows contracts, or requires `instanceof` checks at callsites.
- **I**nterface-segregation: fat interfaces where most implementers stub-out half the methods.
- **D**ependency-inversion: high-level modules importing concrete low-level adapters directly (no seam, no test substitute).

### 3. DRY violations

- Block-duplicate code (≥6 lines repeated ≥3 times, modulo identifier renaming).
- Parallel branches that diverge only in a constant (extract parameter).
- Same domain rule encoded in >1 place (model + form + service all clamp the same range).
- Skip: incidental similarity (two CRUD endpoints that look alike but mean different things — duplication is **knowledge**, not text).

### 4. YAGNI / dead-code

- Premature abstractions: interface with one implementation that has no test-substitute or alternative on the horizon.
- Unused parameters, branches, config keys, feature flags older than the cleanup horizon.
- Speculative generality: `*Manager`, `*Helper`, `*Util` modules with grab-bag methods.
- Orphaned exports — public surface no callsite consumes.
- Skip: framework-required scaffolding (Laravel kernel files, React-Router-data routes) even if locally unused.

### 5. Naming + comment-drift

Identifier-level and comment-level **intent vs text** mismatches.

- Entity-name drift: same concept named ≥2 ways across layers (`Order` in model, `Booking` in service, `Reservation` in API).
- Mechanism-focused names (`FooHandler`, `ProcessorImpl`, `XController2`) where a domain name exists.
- Abbreviation mismatch: `usr` in one file, `user` in the next.
- Misleading names: `getOrder()` that mutates, `isReady` that does I/O.
- Lying comments: `// returns null on error` next to code that throws.
- Outdated TODOs older than NNN days with no issue link.
- Public API undocumented where consumers exist outside the module.
- Cross-reference `CONTEXT.md` glossary when present.
- Skip "well-named code with no comment" — target state, not a finding.

### 6. Coupling / cohesion — **local / structural**

Module-to-module relationships at the file/class scale.

- Feature envy: method on A that reads/writes B's fields more than its own.
- Shotgun surgery: one logical change forces edits across N>3 files in unrelated layers.
- Divergent change: one module edited for unrelated reasons by different stories.
- God modules: file or class >NNN LOC (project's own 95th-percentile threshold) doing >3 unrelated jobs.
- Hidden temporal coupling: caller must invoke `init()` then `prepare()` then `run()` in that order with no compile-time check.
- Hidden global state: implicit singletons, ambient context, module-level mutables that callers must remember.

### 7. Layer / dependency direction — **global / architectural**

Whole-codebase shape: which directions imports may flow.

- Architecture rules violated: UI imports DB driver directly, domain imports framework, infrastructure imports use-case.
- Circular package dependencies.
- Cross-bounded-context reach-through (`OrdersService` reaching into `Inventory.internals`).
- Skip when no documented architecture exists — flag the absence ("no layering rules declared"), don't invent one.

### 8. Error handling / failure modes

How the codebase represents and propagates failure.

- Swallowed exceptions (`catch (e) {}`, `rescue => nil`).
- Silent fallbacks that mask the failing branch (`return null` where the caller can't distinguish "not found" from "lookup failed").
- Mixed paradigms: same module mixes thrown exceptions, returned `Result`/`Either`, and out-params for the same kind of failure.
- Retries without backoff, jitter, or a max-attempts ceiling.
- Async fire-and-forget: promises/goroutines whose rejection has no handler.
- Race-condition smells: shared mutable state crossed by concurrent paths without a lock, channel, or atomic.
- Cross-reference [`error-handling.mini.md`](error-handling.mini.md) for the prescriptive side.

### 9. Type safety / contract clarity

How clearly the code expresses what it accepts and returns.

- Escape-hatch types overused: `any`, `unknown`, `interface{}`, `dynamic` past system boundaries.
- Stringly-typed APIs: enums encoded as raw strings without a closed-set type or validation at the edge.
- Missing nullability: nullable returns typed as non-null (and vice-versa); call sites guarded inconsistently.
- Boolean-flag arguments that change behavior (`foo(true, false, true)` at the callsite).
- Magic numbers / strings encoding domain meaning, no named constant or enum.
- Skip in untyped languages where idiomatic style accepts duck-typing — flag only contracts that consumers visibly misuse.

## Severity tagging

Every finding gets one tag:

- **🔴 Blocker** — correctness or security implication (e.g. SOLID/DIP violation that prevents tests; layering violation that leaks secrets across contexts).
- **🟠 High** — actively costing change-velocity now; fix in the next refactor sprint.
- **🟡 Medium** — would catch a future change off-guard; fix opportunistically.
- **🟢 Low** — style / consistency; bundle into ambient cleanup.

If <10% of findings are 🔴/🟠, the audit is probably pedantry. If >40% are 🔴, the audit is probably catastrophising. Re-triage.

## Output contract

When invoked by `/ai:audit-architecture` or used directly:

1. Markdown report at `docs/reviews/<YYYY-MM-DD>-<scope>-architecture-audit.md`.
2. Top of report: stack detected, scope (paths walked), file count, total LOC, audit duration.
3. One section per dimension. Skip dimensions with zero findings (note "covered, no findings"), don't pad.
4. Each finding: `path:line` · severity · one-line problem · one-line evidence · one-line fix-direction.
5. Bottom of report: tech-debt rolling table (`[ID, finding, severity, fix-direction, owner-suggested]`) — copy-paste-ready for batch issue-filing.
6. **No code-fixes in the audit run.** Fixing is a separate skill / explicit follow-up.

## Anti-patterns

- Auditing dimensions the project doesn't claim — e.g. flagging "no Repository pattern" in a 200-LOC script.
- Surfacing the same root-cause in 8 places — one entry per root-cause, list affected paths underneath.
- Mixing audit (read-only) with fix (write) in one pass — they have different review-thresholds.
- Skipping the severity triage to ship a longer report — length is not the metric.

## Final checklist

- All 9 dimensions visited (or explicitly marked "out of scope" with reason)?
- Findings de-duplicated by root-cause, not by symptom?
- Severity distribution sane (not all 🔴, not all 🟢)?
- Report path follows `docs/reviews/<date>-<scope>-architecture-audit.md`?
- Tech-debt rolling table at the bottom, ready for `gh issue create` batch?
- Zero code-changes in this run?
