---
name: latest-stable-deps
description: When adding or bumping a dependency, prefer the latest stable release; in production-phase repos pair the bump with a migration plan
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Latest stable deps

When you add a new dependency or bump an existing one, use the latest
stable release of that package — not whatever version is mentioned in a
six-month-old blog post or your training-data snapshot. Stable means
released, not a release-candidate / alpha / nightly.

## Why

The default LLM failure mode here is "freeze a dep at training-data
version". The named version often:

- has known CVEs the upstream has since patched,
- references APIs that have since been renamed or removed,
- pins the project to an EOL release line.

A one-line check against the upstream registry costs ~5 seconds and
prevents a deferred upgrade later.

In **production-phase** projects this rule changes shape: latest stable
is still the target, but the bump lands with a migration plan and an
explicit window — not in a drive-by commit. The phase is set in
`.ai-kit-setup` under `branches.lifecycle`; see
[`project-lifecycle.mini.md`](../project-lifecycle.mini.md) for the
matrix.

## How to apply

1. **Before declaring a version, check the registry.**
   - npm: `npm view <pkg> version`
   - PyPI: `pip index versions <pkg>` (or `pip install <pkg>==` and read
     the error)
   - Composer: `composer show <pkg> --available | head`
   - Cargo: `cargo search <pkg> --limit 1`
2. **Quote the actual version** in the manifest. No caret-only ranges
   when adding a new dep; pin a specific stable version, then loosen if
   the project policy says so.
3. **In production phase**, file the bump as its own PR (or its own
   commit) with a one-line migration note: breaking changes since the
   previous version, runtime/SDK assumptions touched, smoke-test plan.
4. **Avoid pre-release tags** unless the user asked for them
   (`-rc.*`, `-alpha.*`, `-beta.*`, `-nightly`).

## When to skip

- The user explicitly pinned the version with a reason ("stay on 4.x,
  5.x changed the validator").
- The repo has a documented dep-pinning policy (a lockfile policy doc,
  Dependabot config that gates major bumps, etc.) — follow the policy.
- Pre-release software is the upstream's only available channel for the
  feature you need; document the choice in the PR.

## See also

- [`project-lifecycle.mini.md`](../project-lifecycle.mini.md) — phase
  matrix for dep-bump conservatism.
- [`twelve-factor.mini.md`](../twelve-factor.mini.md) — dependency
  isolation principle.
