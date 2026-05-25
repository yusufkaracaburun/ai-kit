---
name: project-lifecycle
description: Calibrate agent caution to project lifecycle phase (development vs production)
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Project lifecycle

Calibrate default behaviour to this project's lifecycle phase. The phase lives in `.ai-kit-setup` under `branches.lifecycle`. Read it before any work that touches schema, public APIs, destructive operations, or backwards-compatibility:

```bash
jq -r '.branches.lifecycle // "production"' .ai-kit-setup
```

Missing key → treat as `production` (safe default). Flip the phase with `/ai:phase <development|production>` or by re-running `/ai:setup`.

## Behaviour contract

Both columns shown so edge cases are easy to calibrate.

| Axis | `production` (default) | `development` |
| ---- | ---------------------- | ------------- |
| Schema migrations | Additive only — one new migration file per change. Never edit a landed migration. | Edit landed migration files directly. Expect `migrate:fresh` / DB resets. |
| Backwards-compat | Keep old API, deprecate, dual-write during rollout. | Break callsites in the same PR. No shims, no deprecation cycle. |
| Defensive code | Guard external boundaries (HTTP, user input, third-party SDKs). Handle plausible prod-only failure modes. | Trust internal code + framework guarantees. No guards for impossible cases. |
| Destructive ops | Confirm + warn before drop table, reset DB, force-push, mass delete. | Proceed without confirm except force-push to main/master. |
| Feature flags | Gate new paths behind a flag until rollout. | Inline new path. No flag gymnastics. |

## When to flip

- `development` → `production` when the project has real users or persistent data you cannot reset.
- `production` → `development` only during major rewrites where reset is acceptable. Flip back the moment users return.

## Out of scope

This phase signal is independent of:

- `setup_mode` (install layout — solo-both / project-only / brownfield).
- Test-coverage thresholds (quality, not phase).
- Dependency policy (locked vs latest).
- Logging verbosity (runtime config).

If a stricter gate is needed (e.g. hard-block destructive ops in production), add a per-skill check or a PreToolUse hook — this rule is prompt-level guidance, not enforcement.
