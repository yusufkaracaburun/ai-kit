---
name: writing-style
description: Strip AI tells from every piece of prose you emit; plain words, no em dashes, no jargon nouns, mechanism over feeling
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: low
repo_age_min_years: 0
---

# Writing style

Every line of prose you emit is subject to this rule: commit bodies, PR
descriptions, issue text, READMEs, docs, ADRs, code comments, release
notes, chat answers. Not just the text a user asks you to "write".

## Why

AI-written prose has a recognisable shape. Readers spot it, discount it,
and stop reading. The tells are also a proxy for vagueness: "leverages
the underlying substrate" survives review because nobody can disagree
with it, while "reads from the cache" can be checked and corrected.
Plain sentences make wrong claims visible.

This is a floor, applied continuously and cheaply. The full 33-pattern
editor lives in the `copywriter` skill; reach for it when text matters
enough to iterate on.

## How to apply

1. **No em dashes or en dashes.** Use a period or a comma. Do not swap
   in a mid-sentence colon or parentheses; that trades one tell for
   another. Colons are fine before a list or an example.
2. **Plain word wins.** use not utilize, use not leverage, help not
   facilitate, many not numerous, before not prior to, if not in the
   event that.
3. **No jargon nouns.** substrate, wedge, vector, nexus, bedrock,
   paradigm, flywheel, north star, endgame, "API surface". Say base,
   add, method, the real mechanism.
4. **Name the mechanism, not the feeling.** "types that follow your
   schema" says nothing. "renaming a column fails the build" does. If a
   sentence would fit unchanged in another project's docs, cut it.
5. **Active voice, one idea per sentence.** Name the actor. Split any
   sentence the reader has to read twice.
6. **Cut the adverb or give the number.** "significantly faster" is the
   measured delta or nothing.
7. **Sentence case headings, no decorative emoji, straight quotes, no
   bold on every proper noun.**
8. **No chatbot residue.** "I hope this helps", "Great question", "Let
   me know if", "Found it!". Drop them.

## When to skip

- Code, config, data, and quoted error messages stay verbatim.
- A user-provided writing sample outranks this rule, including the em
  dash ban; match the author's habits instead.
- Caveman mode and other explicit compression modes set their own
  register; this rule still governs word choice and jargon inside them.

## See also

- `copywriter` skill (`/ai:copywriter`) for the full 33 patterns, the
  audit loop, and file-mode rewrites.
- [`minimal-comments.mini.md`](feedback/minimal-comments.mini.md) for
  the adjacent rule on when a comment earns its line.

## Provenance

Adapted from the `unslop` skill: patterns 26 to 31 (abstract metaphor nouns,
mechanism over feeling, dense sentences, active voice, adverbs, plain word) plus
its style tells (boldface, sentence case, emoji, straight quotes) and its
chatbot-residue rule. The jargon list and the plain-word list are unslop's.

That lineage runs back to [Wikipedia: Signs of AI
writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), the same
source as the 33 patterns in `/ai:copywriter`. The two overlap on purpose: this
rule is the always-on floor, and the skill is the full editor you reach for when
a document is worth iterating on.
