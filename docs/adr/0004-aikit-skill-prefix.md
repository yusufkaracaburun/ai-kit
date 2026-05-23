# ADR-0004: Prefix every skill with ``

## Status

Accepted (v2.0.0)

## Context

ai-kit shipped 20 skills with bare, generic-verb names — `setup`, `review`,
`ship`, `tdd`, `qa`, `triage`, `resume`, and so on. The 5 slash commands were
already namespaced (`doctor`, `which`, …) and so were the 2
subagents (`explore`, `reviewer`), but skills were not.

Generic names collide. A Claude Code session routinely loads skills from
several sources at once — other plugins (`gsd-*`, `caveman-*`, `lazyweb:*`),
the user's own global skills, and Claude's built-ins. ai-kit's `review` skill
and a built-in `review` already occupy the same name; `setup`, `ship`, `init`,
`qa`, `resume` are all generic enough to clash. When two skills share a name,
host routing is ambiguous and the wrong one can fire.

The default one-line installer uses symlinks, dropping skills flat into
`~/.claude/skills/<name>/` with no namespace. The plugin install path
namespaces as `ai-kit:<name>`, but most users take the symlink path.

## Decision

Prefix every ai-kit skill with ``. All 20 skill directories, their
`name:` frontmatter, every cross-reference, eval fixture, golden, and test
moved in lockstep:

`setup → setup`, `review → review`, `tdd → tdd`, … through
all 20 skills.

The prefix is `` (no internal hyphen) to match the existing slash
commands and subagents.

Out of scope:

- **`bin/*.sh` scripts** keep their own `ai-kit-*.sh` convention. They are not
  user-invoked by skill name; renaming them buys nothing.
- **Rules** (`standards/rules/*.mini.md`) are not prefixed. They are generic
  rule books, partly derived from `ciembor/agent-rules-books`, emitted as
  content rather than invoked by name.

## Consequences

**Positive**

- No name collisions with other plugins, the user's own skills, or Claude
  built-ins.
- A skill's origin is obvious from its name — `/ai:ship` is unambiguously
  ai-kit's.
- Consistent with the already-prefixed slash commands and subagents, and with
  the wider ecosystem convention (`gsd-`, `caveman-`).

**Negative**

- **Breaking change.** Anyone who typed `/setup`, `/review`, etc., or whose
  scripts and notes reference the old names, must update. Hence the v2.0.0
  major bump.
- Skill names are longer.

**Follow-ups**

- Existing installs pick up the new names on the next `git pull` + skill
  reload. The old skill directories no longer exist, so a stale `/setup`
  invocation fails fast rather than silently running the wrong thing.
