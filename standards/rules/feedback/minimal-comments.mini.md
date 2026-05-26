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

Well-named identifiers and small functions are self-documenting. A
comment is only worth its keep when it captures something the code
cannot: a hidden constraint, a non-obvious invariant, a workaround for a
specific upstream bug, behaviour that would surprise a careful reader.

## Why

Comments rot faster than code. The compiler does not check them; tests
do not run them; reviewers skim them. A wrong comment is worse than no
comment because it actively misleads. The break-even bar is therefore
high: a comment must be either non-obvious-by-construction, or load-
bearing in a way the code cannot express.

LLMs over-comment by default — restating what the next line obviously
does, narrating control flow, marking task provenance ("added for issue
#42"). All three rot or become noise within weeks.

## How to apply

1. **Before adding a comment, ask: "would removing this confuse a
   future reader?"** If no, drop it.
2. **Comment the WHY, not the WHAT.** `// loop over users` is noise.
   `// HMRC API throttles bursts; sleep keeps us under 5 RPS` earns
   its line.
3. **No task-provenance comments.** "Added for issue #42", "fixes user
   bug", "used by X flow" belong in the PR description and rot as the
   codebase evolves.
4. **One short line.** If the explanation needs a paragraph, the design
   is wrong or it belongs in a docstring / ADR / README.
5. **For Python / JSDoc / Rustdoc**: one-line summary is enough unless
   the surface is a public API with non-obvious parameter semantics.

## When to skip

- Public APIs of libraries / SDKs / generated docs: one-line docstring
  per symbol is normal.
- The hidden-constraint case: a comment that prevents a foreseeable
  refactor from silently breaking something is worth a paragraph.

## See also

- [`pragmatic.nano.md`](../pragmatic.nano.md) — adjacent principle for
  not over-explaining code.
- [`aposd.mini.md`](../aposd.mini.md) — Ousterhout on the comment-is-
  obligation pattern.
