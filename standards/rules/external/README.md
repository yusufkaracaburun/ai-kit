# External rules

Stack-specific rules vendored from the web by `/aikit-recommend-rules`
(Phase 2 → Phase 3). Unlike the canonical rules one level up, these are **not
authored by ai-kit** — they are pinned copies of community sources.

## Conventions

- One file per rule: `<slug>.mini.md`.
- Reference it explicitly with the `external/` prefix:
  `bin/emit-rules.sh <project> --rules external/<slug>`.
- Never `universal: true` — external rules are opt-in only, so the default
  emit (every `universal: true` rule) never picks them up.

## Provenance frontmatter

Every file carries, in addition to the normal rule frontmatter:

| Key | Meaning |
| --- | ------- |
| `source_url` | Permalink to the exact file at the pinned SHA |
| `source_license` | SPDX id of the upstream license |
| `pinned_sha` | Commit SHA the content was copied from |
| `vendored_at` | `YYYY-MM-DD` the copy was made |

## Trust model

- Content is pinned to a commit SHA — never tracks a moving branch.
- Re-vendoring (re-fetch + re-pin) requires explicit user confirmation.
- Do not edit a vendored body in place; it must stay faithful to its source.

See [`workflow/skills/aikit-recommend-rules/SKILL.md`](../../../workflow/skills/aikit-recommend-rules/SKILL.md).
