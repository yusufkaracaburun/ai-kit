# Skill evaluation

ai-kit ships with a lightweight, two-layer eval harness for the skills themselves.

| Layer | What | Where | When |
| ----- | ---- | ----- | ---- |
| **Structural** | Deterministic checks across every `SKILL.md` and fixture | `tests/bin/eval-structure.sh` | Every CI run, every `run-all.sh` |
| **Behavioural** | Rubric-rated runs against scenario prompts | `tests/eval/prompts/` → `tests/eval/results/` | Manual — by you, after a skill change |

There is **no LLM judge** and no A/B harness. The deliberate trade-off: deterministic checks catch drift in skill *shape*; rubric ratings catch drift in *behaviour*, but only when you actually run them. See ADR 0002 for why.

## Structural layer

`eval-structure.sh` runs 11 checks per skill, 4 per agent, 3 per fixture, and one coverage check that every skill has a fixture. Failure halts CI.

Per skill:

1. Frontmatter has `name` and `description`.
2. `name` matches the directory.
3. `name` uses only lowercase letters, digits and hyphens.
4. Frontmatter has no fields beyond `name`, `description`, `argument-hint`, `model`, `disable-model-invocation`, `tools`, `allowed-tools`, `extends`, `strictness`.
5. `description` length is 30–500 chars, single line.
6. `description` contains a trigger phrase (`Use when/before/at/after/during/for` or `when (user|the user|you) …`). Skipped if the skill sets `disable-model-invocation: true`.
7. All relative `.md` links resolve on disk.
8. No unresolved `{{PLACEHOLDER}}` tokens.
9. No tab characters, LF line endings.
10. Skills of 20 lines or more have at least one `## ` heading.
11. Every `subagent_type=ai:<x>` the skill names has a `workflow/agents/<x>.md`.

Per agent (`workflow/agents/<x>.md`): `name` matches the file, has a `description`, a pinned `model:` carries a `<!-- model-pin: <reason> -->` line, and at least one skill names it.

Per fixture (`tests/eval/prompts/<skill>/<scenario>.md`):

- Has `id:` and `skill:` in frontmatter.
- `skill:` matches the parent directory name.
- `expects:` has at least one bullet.

Run locally:

```bash
./tests/bin/eval-structure.sh
```

## Behavioural layer

1. Pick a skill change you want to validate.
2. Dump the fixture + skill + rating template:

   ```bash
   ./bin/eval-skill.sh diagnose null-pointer-react
   ```

3. Paste the fixture body into Claude Code or Cursor against the current skill.
4. Score the response against the printed checklist.
5. Save the filled rating to `tests/eval/results/YYYY-MM-DD-<skill>-<scenario>.md` (the path is suggested in the dump output).

`tests/eval/results/` is gitignored — these are personal notes, not CI artifacts. Keep them for your own diffing across versions.

## Adding a new fixture

1. Pick a scenario where the skill should behave *distinctively* — something a generic LLM would get subtly wrong without the skill.
2. Create `tests/eval/prompts/<skill>/<scenario>.md`:

   ```markdown
   ---
   id: <kebab-case-id>
   skill: <skill-name>
   expects:
     - <observable behaviour 1>
     - <observable behaviour 2>
   ---

   # Prompt

   <the exact text to paste into the agent>
   ```

3. Rubric items must be **observable** — "asks before assuming" is good, "is thoughtful" is not.
4. Re-run `./tests/bin/eval-structure.sh` to confirm the fixture lints.

## Which skills are covered

Every skill in `workflow/skills/` has at least one fixture; the coverage check fails the run when one is missing.

## Out of scope (today)

- LLM-as-judge auto-scoring — non-deterministic, costs money, low ROI for a solo kit.
- A/B comparison between skill versions — comes when there's enough fixture history.
- Cross-IDE divergence (Claude Code vs Cursor) — interesting but not actionable yet.
- Per-step timing or token budgets.
