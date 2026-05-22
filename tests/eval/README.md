# Eval harness

Two complementary layers, both deterministic, both runtime-free.

## Layer 1 — structural checks (every skill)

`tests/bin/eval-structure.sh` validates that every `SKILL.md` and every
fixture is well-formed: frontmatter keys are recognised, descriptions have
trigger phrases, relative links resolve, etc. It does not look at output
quality — only at the shape of the artefacts.

Fixtures live at `tests/eval/prompts/<skill>/<scenario>.md` and define:

- An input prompt for a model.
- A prose `expects:` list — human-readable rating criteria.

## Layer 2 — golden-output rubric (high-stakes skills)

For the skills where output quality matters most (`aikit-to-prd`, `aikit-tdd`, `aikit-ship`),
we also keep a *golden output*: a hand-written response that demonstrates
what "good" looks like. Each golden carries a structured rubric in its
frontmatter that can be checked deterministically (no API calls, no LLM).

Goldens live at `tests/eval/goldens/<skill>/<scenario>.md`.

### Rubric format

```yaml
---
id: <scenario>
skill: <skill>
required_headings:
  - "## Problem Statement"
required_keywords:        # case-insensitive substring match
  - "ready-for-agent"
required_phrases:         # case-SENSITIVE substring match
  - "ONE failing test"
forbidden_keywords:       # case-insensitive; must NOT appear
  - "TODO"
min_lines: 50             # body line count (after frontmatter)
max_lines: 400
---

(body — the ideal response)
```

### Running the rubric

```bash
# Validate every golden against its own rubric (CI default).
bin/eval-golden.sh --validate-all

# Validate one golden against its own rubric.
bin/eval-golden.sh aikit-to-prd recurring-tasks

# Score a real model response against the rubric.
bin/eval-golden.sh aikit-to-prd recurring-tasks path/to/response.md
```

Exit codes: `0` all checks pass, `1` one or more failed, `2` usage error.

### Why the rubric lives with the golden (not the fixture)

The fixture is *input*. The golden is *the answer*. The rubric describes
what makes the answer correct, so it belongs with the answer. Keeping
them together makes drift easier to spot: if you weaken one without
weakening the other, the CI check (golden-passes-own-rubric) catches it.

### Manual flow (Layer 1 + Layer 2 together)

`bin/eval-skill.sh <skill> [<scenario>]` dumps the fixture prompt and
`SKILL.md` to stdout so you can paste them into Claude Code or Cursor and
collect a real response. After you paste the response into
`tests/eval/results/<date>-<skill>-<scenario>.md`, you can score it:

```bash
bin/eval-golden.sh <skill> <scenario> tests/eval/results/<date>-<skill>-<scenario>.md
```

The output tells you which structural checks the response missed, which
gives a sharper signal than reading prose `expects:` items one by one.

## Adding a new golden

1. Pick a fixture that already exists at `tests/eval/prompts/<skill>/<scenario>.md`.
2. Hand-write the ideal response at `tests/eval/goldens/<skill>/<scenario>.md`
   with a rubric in the frontmatter.
3. Run `bin/eval-golden.sh <skill> <scenario>` — it must pass its own rubric.
4. Run `./tests/bin/run-tests.sh` — `eval-golden --validate-all` must stay
   green, and the per-priority-skill existence assertions must still pass.

Keep goldens realistic in length (200–500 lines of body is plenty); a
golden is a regression baseline, not a textbook.
