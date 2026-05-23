---
id: incoming-bug
skill: triage
expects:
  - identifies the triage role being applied (e.g. reporter, owner, AFK-prep)
  - assigns or asks for a priority/severity using the project's labels
  - checks if the issue is AFK-ready (clear repro, no open decisions) before promoting
  - does NOT silently change state without naming the next state and why
  - flags duplicates or related issues if any
---

# Prompt

A user just filed "Checkout fails with 500 on Safari iOS" via the bug
template. Triage it — figure out if it's AFK-ready, what label set it needs,
and what's missing before someone can start on it.
