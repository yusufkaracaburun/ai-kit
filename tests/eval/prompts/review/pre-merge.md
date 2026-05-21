---
id: pre-merge
skill: review
expects:
  - reads CONTEXT.md and relevant ADRs before reviewing diff
  - checks security (auth/authz, input validation, secrets) explicitly
  - checks test coverage of the diff (not just total coverage)
  - distinguishes BLOCKERS (must-fix) from suggestions (nice-to-have)
  - flags scope creep — code outside the stated PR purpose
---

# Prompt

Review my current branch before I open a PR. It adds rate-limiting to the
public API endpoints. I want a real review — block me on anything that
matters, don't just nod.
