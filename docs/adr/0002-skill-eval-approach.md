# ADR-0002: Two-layer skill eval, no LLM judge

## Status

Accepted (v1.1.0)

## Context

After v1.0.0 there was no way to tell whether a skill change improved behaviour or just changed it. Three obvious options:

1. **LLM-as-judge.** Run each skill against a corpus of prompts, score with another LLM call against a rubric. Industry-standard, slick.
2. **Pure structural checks.** Lint SKILL.md frontmatter, link integrity, length. Cheap, deterministic, but doesn't catch behaviour drift.
3. **Manual rubric ratings.** Dump prompt + skill to stdout, paste into Claude/Cursor, rate the output against a checklist by hand.

## Decision

Ship **structural + manual rubric**. Skip LLM-judge in v1.1.0.

The harness:

- `tests/bin/eval-structure.sh` runs 8 deterministic checks per SKILL.md and 3 per fixture. Hooked into CI. Catches *shape* drift (broken links, missing frontmatter, lost `## Process`).
- `bin/eval-skill.sh <skill> <scenario>` dumps a fixture + skill + rating template. The user pastes, runs in agent UI, scores. Results land in `tests/eval/results/` (gitignored — personal log).

## Consequences

**Positive**

- Zero API cost, zero non-determinism in CI.
- Trivial to add fixtures: one markdown file per scenario.
- The user sees the actual agent output, not a judge's verdict — surfaces drift the judge would miss.
- A new skill cannot land without passing structural checks.

**Negative**

- Behavioural eval is on the honour system. Nothing fails CI if the user never runs `eval-skill.sh`. Accepted: this is a solo kit; the discipline is on the user.
- No A/B comparison across skill versions.
- "Was the answer good?" requires reading the answer. We pay this cost on purpose — the LLM judge would skip it for us, badly.

**Revisit when**

- The kit gets a second active contributor (rubric scaling matters).
- 30+ fixtures exist and you need to diff a skill change across all of them.
- An LLM-judge model gets cheap and faithful enough that the trade is favourable. Today, it isn't.
