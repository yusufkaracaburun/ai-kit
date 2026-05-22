# Skill showcases

Real outputs from running ai-kit skills on a realistic project — proof that the skills produce concrete, valuable work, not just templates.

Each entry pairs the **input prompt** (or session brief) with the **output the skill produced**. Sources are either:

- **Anonymised real runs** (sanitised: no client names, no production credentials, no PII).
- **Synthetic but realistic** runs against a fictional domain — clearly labelled.

## Convention

```
.examples/skills/
├── README.md                  # this file
├── <skill>/
│   └── <scenario>.md          # one self-contained walkthrough
```

Each `<scenario>.md` contains:

1. **One-line context** — what the project is, what was asked
2. **Source flag** — `real-anonymised` or `synthetic`
3. **Prompt** — exactly what the user typed (or session goal)
4. **Output** — the artefacts the skill produced (file diffs, ADRs, summaries, etc.)
5. **Commentary** — what about this output sets the bar for the skill

## Coverage

| Skill | Showcase(s) |
| ----- | ----------- |
| `aikit-grill-with-docs` | [library-saas](grill-with-docs/library-saas.md) |
| `aikit-setup` | see [`.examples/`](../README.md) walkthroughs |
| (others) | _open — contribute one_ |

To contribute a showcase: copy an existing entry as a template, redact, and PR. Showcases are reviewed against the `expects[]` rubric in `tests/eval/prompts/<skill>/`.
