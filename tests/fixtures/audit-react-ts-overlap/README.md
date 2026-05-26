# audit-react-ts-overlap fixture

Minimal React 19 + TypeScript 5.7 sample. Used by
`tests/bin/cases/audit-extension-contract.sh` to verify the per-stack
extension ownership contract (`standards/contracts/audit-architecture-extension.contract.md`).

## What's in it

- `src/Dashboard.tsx` — React-shaped smell only (props-bloat).
  Owned by `audit-architecture-react` heuristic **R2** under dimension #6.
- `src/api.ts` — TS-shaped smells only (`any` boundary leak, `as` cast).
  Owned by `audit-architecture-typescript` heuristics **T1** + **T2** under #9.

## Why this exists

When both `audit-architecture-react` and `audit-architecture-typescript`
extensions are loaded against this fixture, the contract-test asserts:

1. Every finding row appears **exactly once** (no duplicate `path:line`
   across `[react]` + `[typescript]` prefixes).
2. At least one `[react]`-prefixed finding is present.
3. At least one `[typescript]`-prefixed finding is present.

The React and TypeScript extensions land in issues #81 and #82. Until
then, the per-extension assertions are XFAIL but the fixture-shape
assertions (files exist + structure correct) run green.
