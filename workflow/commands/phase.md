---
description: Read or flip the project lifecycle phase (development | production) — calibrates every ai-kit skill's default caution.
argument-hint: "[development|production]"
allowed-tools: Bash
---

Read or set this project's lifecycle phase.

!`bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-phase.sh" $ARGUMENTS`

If no argument: prints the current phase (default `production` when unset).

If the user passed `development` or `production`: the marker key
`branches.lifecycle` is updated. The canonical rule
`project-lifecycle.mini.md` reads this key and emits the matching behaviour
contract on every session — restart Claude Code to apply.

Phase semantics live in `standards/rules/project-lifecycle.mini.md`. Summary:

- `development` — no real users, data resetable, edit landed migrations, no
  backwards-compat shims, no defensive code for impossible cases.
- `production` — additive migrations, keep old API, dual-write during rollout,
  destructive ops gated.

For a full re-setup walkthrough use `/ai:setup` instead.
