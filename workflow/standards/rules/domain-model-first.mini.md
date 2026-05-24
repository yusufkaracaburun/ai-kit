---
name: domain-model-first
description: Before proposing any architecture or data-model change, read the canonical domain entities the change would touch — don't extrapolate from the surface layer (form, controller, route)
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Domain-model first

When the user asks an architecture or data-model question — "how do we
model X", "where does Y live", "what's the schema for Z", "add a setting
for X to this tenant" — read the canonical domain entities *before*
proposing anything. Surface layer (form, controller, route, template) is
not enough; the answer lives one layer deeper, in the ORM models / schema
/ aggregations / pivots that the surface layer reads from.

## Why

The default LLM failure mode is **domain-model blindness**: grep for the
feature name, read the route/controller, propose a parallel abstraction
next to a first-class model that already exists. The user pays the cost
later as a refactor.

A single extra `Read` on the relevant model file (~5 seconds) prevents
the parallel-abstraction proposal (~1 hour to undo, plus trust erosion).
Cost asymmetry favours always-read.

This rule is the same shape as `verify-state-before-claims`, one layer
up: don't claim a domain concept needs to exist before checking the
canonical source that already owns that concept.

## When the gate fires

Trigger when **any** of these is true:

- User question contains architecture/schema verbs near a domain noun:
  "model", "relation", "schema", "where does X live", "how do we
  represent", "add a setting / field / column for", "is X a first-class
  concept".
- User question names an entity that appears in `CONTEXT.md` /
  `CONTEXT-MAP.md` / `docs/architecture.md` glossary.
- Source doc (issue, PRD, ADR) proposes a new model, table, migration,
  or settings key for a concept that *might* already exist in the
  domain layer.
- About to propose a migration, new table, new model, new pivot, or
  new settings namespace.

## How to apply

1. **Locate the canonical domain layer.** Stack-specific defaults:
   - Laravel → `app/Models/`, `app/Domain/`, `database/migrations/`
   - Rails → `app/models/`, `db/schema.rb`
   - Django → `*/models.py`, `*/migrations/`
   - Prisma / Drizzle → `prisma/schema.prisma`, `drizzle/schema.ts`
   - DDD layouts → `src/<context>/domain/`, `lib/<domain>/`
   - JPA / Hibernate → `*/entity/`, `*/repository/`

2. **Read at minimum:** the entity the question names, plus any entity
   it relates to (BelongsTo / HasMany / pivots / aggregations). Skim
   the first 80 lines and any method named after the concept in
   question (`->subsidies()`, `isFrozen()`, `totalRequestedHoursPerYear()`
   etc. — these are the canonical operations).

3. **Verify, don't assume.** If the model file references a pivot or
   settings namespace, open that too. The user's question often hinges
   on a relation that exists in code but not in their mental model.

4. **Prefix the proposal with evidence.** "Read `Subsidy.php`
   (lines 1-80), `Coalition.php` (lines 120-180), verified
   `Coalition->subsidies()` already exists" → then propose. The prefix
   is the contract: it lets the user check your reading instantly.

5. **Prefer extending existing entities** over parallel ones. A new
   field on `Subsidy` beats a new `compliance.subsidy_program` setting
   that bypasses it. State why if proposing parallel — sometimes it's
   right (different bounded context, different lifecycle), but
   "didn't know it existed" is never a valid reason.

## When to skip

Only skip when one of:

- The change is purely cosmetic (rename, comment, formatting, docs
  edit that doesn't touch domain semantics).
- The user explicitly says "don't bother reading the models, I know X
  is new" — and the change is small enough that a wrong assumption is
  cheap.
- The repo has no domain layer (a flat script, a config-only repo,
  a static site). Then there is nothing to read first.

## Anti-pattern

> "The user asked how to track subsidy overlap. I grepped for 'subsidy',
> found the settings UI, proposed a new `compliance.subsidy_program`
> tenant-setting with a 3-state enum. Migration + UI toggle + state
> machine."

vs. the canonical state that already existed:

```text
Subsidy (central)              ← seeded with programme_code='so_2025'
SubsidyApplication (pivot)     ← Coalition ↔ Subsidy with status + granted_at
Coalition->subsidies()         ← BelongsToMany, already aggregated by
                                 totalRequestedHoursPerYear()
Tenant ↔ Coalition             ← coalition_tenants pivot
Tenant->settings('subsidy.*')  ← already in production
```

One `Read` on `Subsidy.php` + `Coalition.php` would have surfaced this.

## See also

- [`grill-first.mini.md`](./grill-first.mini.md) — open with grill
  questions before planning. Domain-model-first is one specific
  grill: "what does the domain layer already know about this?"
- [`context-discipline.mini.md`](./context-discipline.mini.md) — keep
  the model-reads scoped; if a wide sweep is needed, delegate to the
  `Explore` sub-agent so raw file contents don't fill the conversation.
- [`ddd-distilled.mini.md`](./ddd-distilled.mini.md) — the language
  /entities/relations vocabulary this rule operates on.
