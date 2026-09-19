---
name: minimal-comments
description: Default to no comments; only add one when the WHY is non-obvious and would surprise a future reader
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: medium
repo_age_min_years: 0
---
# Minimal comments

Well-named identifiers and small functions document themselves. A comment earns its line only for what the code cannot say: a hidden constraint, a non-obvious invariant, a workaround for a specific upstream bug, behaviour that would surprise a careful reader. Comments rot faster than code — nothing checks them — and a wrong one misleads; LLMs over-comment by default (restating the next line, narrating control flow, "added for issue #42").

- Before adding one: would removing it confuse a future reader? No → drop it.
- WHY, not WHAT. `// loop over users` is noise; `// HMRC throttles bursts; sleep keeps us under 5 RPS` earns its line.
- No task provenance ("fixes user bug", "used by X flow") — that belongs in the PR and rots.
- One short line. A paragraph means the design is wrong or it belongs in a docstring / ADR / README. Exception: a hidden constraint that stops a foreseeable refactor from silently breaking something may take a paragraph.
- Public library / SDK surfaces and generated docs: one-line docstring per symbol is normal; longer only when a public API's parameter semantics are non-obvious.

See `pragmatic.nano.md`, `aposd.mini.md` (Ousterhout on comments as obligation).
