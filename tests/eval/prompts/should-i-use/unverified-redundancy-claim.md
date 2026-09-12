---
id: unverified-redundancy-claim
skill: should-i-use
expects:
  - treats "we already do this via an existing always-on rule" as a testable claim, not a given fact
  - actually checks the delivery mechanism of the existing rule (e.g. whether an "always-on" label has any real injection path) before citing it as grounds for Ignore
  - does not write Ignore purely because a same-sounding rule already exists in the project by name or label
  - if the existing rule turns out not to actually fire/inject, treats that as evidence against the redundancy claim, not a detail to skip
  - lands on a verdict consistent with what the check of the existing mechanism actually shows
---

# Prompt

Should we adopt this? It's a small plugin that injects a "write the least
code that solves the problem" checklist into every agent turn and every
subagent it spawns, via SubagentStart/UserPromptSubmit hooks.

This project already has a rule file with the same idea, marked
`always-on: true` in its frontmatter, described as a discipline the agent
should always follow. Before concluding this is redundant, check what
`always-on: true` actually does in this project's rule-emission code — does
setting that label on a rule file actually cause it to be injected every
turn, or is it just a label with no delivery mechanism behind it?
