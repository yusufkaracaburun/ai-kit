---
id: rule-copy-left-behind
skill: review
expects:
  - reads the brief's Rule changed field (norm per year → norm per period) and greps for other copies of the rule
  - reports the frontend component that still computes the norm per year as a blocker, citing file and line
  - reports the label that still says "per jaar" as a blocker, citing file and line
  - verdict is not APPROVE
---

# Prompt

Review my branch before I open a PR. The Agent Brief says
`Rule changed: norm per year → norm per period`. I updated the backend
calculation and its tests. Block me on anything that matters.

Context the reviewer should find on its own: a frontend component still
divides the yearly norm itself (per year), and a form label still reads
"Norm per jaar".
