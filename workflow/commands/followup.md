---
description: One-shot defer capture — open a GitHub issue in house style and append a roadmap entry referencing it.
argument-hint: "<one-line lead> [--label <name>]"
allowed-tools: Bash, Read, Edit, Write
---

Invoke the `followup` skill with the user's lead as input.

The lead is `$ARGUMENTS` — a one-line summary of the work being deferred. Optional `--label <name>` overrides the default `enhancement` label.

Read [`workflow/skills/followup/SKILL.md`](../skills/followup/SKILL.md) for the full process, then run it against the current repo:

1. Read the lead and any context already in the conversation.
2. Detect environment (`gh` auth, remote, roadmap presence).
3. Draft the issue body in house style and the roadmap paragraph.
4. Show both to the user and ask **once** before mutating.
5. On approval: `gh issue create …`, then append the roadmap entry, then commit.
6. Report the issue URL + roadmap line number.

If the lead is empty, ask the user for it before doing anything else.
