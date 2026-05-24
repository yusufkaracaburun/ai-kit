---
name: semver
description: Semantic versioning — MAJOR.MINOR.PATCH discipline for any released artifact
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: low
repo_age_min_years: 0
---

# Semantic versioning

Every released artifact (package, plugin, schema, public API) follows
`MAJOR.MINOR.PATCH`. The version is a contract with consumers — bump it
according to *their* upgrade burden, not your effort.

## Bump rules

- **MAJOR** — any change a consumer must adapt to: removed/renamed public
  function, signature change, behavior change that breaks existing callers,
  config key removed, response shape changed, env-var rename.
- **MINOR** — backwards-compatible new capability: new function, new
  optional argument, new endpoint, new config key with a default.
- **PATCH** — backwards-compatible fix: bug fix, performance improvement,
  documentation fix that doesn't change behavior.

## Hard rules

- **No silent breaking changes.** If consumers must change anything, it's MAJOR.
- **Pre-1.0 (0.x.y)** — anything can break in a MINOR bump. Tell consumers
  with a banner in the README.
- **Tag every release.** `git tag vX.Y.Z` + `git push --tags`. Untagged
  versions strand downstream pinned consumers.
- **CHANGELOG.md updated in the same commit as the version bump.** No
  "I'll write the changelog later".
- **Deprecate before remove.** Mark for removal in MINOR N, remove in
  MAJOR N+1. Never skip the deprecation cycle.

## What counts as "public API"

Anything documented for external use:

- Exported symbols in package code
- HTTP routes, GraphQL schema, gRPC services
- CLI flags + subcommands
- Config-file keys, env-var names
- Database schema if external consumers query it
- Plugin / hook contracts

Internal helpers can change freely without a version bump — but if a
"private" helper has external users, it isn't private; treat it as public.

## See also

- [`api-design.mini.md`](./api-design.mini.md) — versioning HTTP APIs.
- [`release-it.mini.md`](./release-it.mini.md) — release-ready discipline.
- semver spec: https://semver.org/
