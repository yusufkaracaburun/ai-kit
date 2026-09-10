# ADR-0001: Four setup modes, not six

## Status

**Superseded by [ADR-0012](0012-setup-mode-decomposition.md) (2026-09-10).**
The plugin marketplace channel this ADR never anticipated made the
`install-global` axis ambiguous (symlink-install vs plugin), and
brownfield turned out to only ever gate six Tier-B defaults, not a
distinct linking behavior — see ADR-0012 for the decomposition. This ADR
is preserved as historical record of the v1.0.0 reasoning.

Accepted (v1.0.0)

## Context

`/ai:setup` needs to ask the user the smallest number of questions that still picks the right configuration. Earlier drafts (v0.3) had six modes covering every permutation of "global skills yes/no", "project skills yes/no", "rules yes/no", and "brownfield yes/no". The branch tree was so deep that the interactive setup felt like a survey instead of an onboarding.

## Decision

Collapse to four modes:

| Mode | When |
| ---- | ---- |
| `solo-both` | Greenfield default — global + project merge-skills |
| `solo-global` | Machine-wide skills only |
| `project-only` | Project-scoped skills only |
| `brownfield` | Existing rules / MCP / custom skills — coexistence documented |

Brownfield isn't really about *what* the user wants; it's about *what's already there*. So `detect-tooling.sh --json` answers the brownfield question for the user — they only need to confirm.

Result: one question covers the entire matrix.

## Consequences

**Positive**

- Tier A is a single setup-mode question + bootstrap + dev-env. ~5 minutes.
- The agent stack is documented (`docs/agents/agent-stack.md`) only when there's something to document.
- Less surface for tests; brownfield detection has its own fixture and assertions.

**Negative**

- Edge case: a user who wants project-only AND has an existing `.cursor/rules` falls in `brownfield`, not `project-only`. The marker captures both pieces of info; the human-friendly label is `brownfield`. Acceptable.

**Follow-ups**

- If a fifth mode emerges (e.g. team-shared global), revisit. Don't pre-add it.
