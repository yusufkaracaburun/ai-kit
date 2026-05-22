# Architecture

How this repo is structured — for agents navigating frontend and backend code.

## Frontend

**Approach:** [e.g. follow existing layout | co-located components | feature folders | FSD-like | pages/routes]

**Layout:** [key paths, e.g. src/features/, app/pages/]

**Conventions:**

- [Where new UI code goes]
- [Testing location for UI]

**Reference:** [ADR link or official docs — optional]

## Backend

**Approach:** [e.g. framework defaults | layered | actions | ports-adapters | modular monolith]

**Layout:** [key paths, e.g. app/Actions/, src/Domain/]

**Conventions:**

- [Where new API/domain code goes]
- [Testing location for backend]

**Reference:** [ADR link — optional]

## Cross-cutting

- Monorepo boundaries: [apps/libs if applicable, else n/a]
- New features go: [where to add FE + BE code]
- Deeper reviews: use `aikit-improve-codebase-architecture`; new patterns → ADR via `aikit-grill-with-docs`
