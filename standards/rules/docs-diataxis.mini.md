---
name: docs-diataxis
description: One document, one mode — tutorial, how-to, reference, or explanation. Pick the mode before writing and do not mix them.
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# Pick the document mode first

Two questions pick the mode. Does the content serve doing or thinking? Does it
serve learning or work?

| | Learning | Work |
| --- | --- | --- |
| **Doing** | tutorial | how-to |
| **Thinking** | explanation | reference |

**Tutorial.** The reader learns by building something. You are the teacher and
their success is your job. Say what they will build, not what they will learn.
Every step shows a visible result: the output, the log line, the changed prompt.
Cut explanation to one clause and a link.

**How-to.** The reader has a problem and wants it solved. Assume competence and
skip the teaching. Steps only. Name the guide after the task: "How to rotate the
API key", not "API key rotation".

**Reference.** The reader looks something up. Describe and nothing else: no
instruction, no opinion. State facts, options, limits, and errors without
hedging. Mirror the structure of the thing described. Generate from code where
you can, so it stays true.

**Explanation.** The reader wants to understand why. One bounded topic, readable
away from the product. Give the design decisions, the history, the constraints,
and the alternatives. This is the only mode where opinion belongs.

## Do not mix

No reference table inside a tutorial. No hand-holding inside reference. No
argument inside a how-to. When a document needs two modes, split it and link the
halves.

Use the compass on one sentence when a paragraph feels wrong. Gut feel misreads
this often.

## Provenance

Adapted from [Diátaxis](https://diataxis.fr) by Daniele Procida. This rule is
the structural layer only. Sentence-level style lives in
[`writing-style.mini.md`](writing-style.mini.md), and the full prose editor is
`/ai:copywriter`.
