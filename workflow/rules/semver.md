---
paths: ["**/CHANGELOG*", "VERSION", "package.json", "pubspec.yaml", "composer.json"]
---
<!-- ai-kit global rule (ADR-0015): Semantic versioning — MAJOR.MINOR.PATCH discipline for any released artifact -->
<!-- Source: standards/rules/semver.mini.md — re-stamp with bin/sync-plugin-rules.sh -->


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
  versions strand downstream pinned consumers. An artifact that ships with
  a build number (app stores) tags version *and* build — `v1.6.2+61` — the
  store shows the build, and one version can have several; build numbers
  are monotonic across versions, never reused.
- **CHANGELOG.md updated in the same commit as the version bump.** No
  "I'll write the changelog later". Stronger: the commit that changes
  user-visible behavior writes its own line under `## [Unreleased]` — whoever
  writes the commit knows what changed; three weeks later nobody does. The
  bump then only dates the section, and the store text is that section,
  shortened.
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

- `api-design.mini.md` — versioning HTTP APIs.
- `release-it.mini.md` — release-ready discipline.
- semver spec: https://semver.org/
