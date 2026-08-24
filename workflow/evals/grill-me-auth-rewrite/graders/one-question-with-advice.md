---
type: llm
criteria: |
  Does the response conclude by probing exactly ONE topic or branch, and does
  it offer a recommended answer to that question with a one-line reason why,
  giving the user something to push against? Rephrasings or restatements of
  the same underlying question count as ONE question. Fails only when the
  response probes two or more DIFFERENT topics at once, or attaches no
  recommendation to the question it asks.
---

Phase 2 contract of grill-me: one question at a time, recommendation attached.
