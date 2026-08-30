---
name: contribute-eval
description: Turn a skill failure into a regression test by contributing a new eval case (prompt fixture + golden) to the ai-kit eval suite. Use when user says "this skill failed", "ai-kit got this wrong", "add a test for this", "contribute eval", "/ai:contribute-eval", or whenever an ai-kit skill output is materially worse than the user expected and the user wants the fix to stick.
---

# Contribute eval

Capture one ai-kit skill failure as a structured eval case — a prompt fixture plus a golden rubric — and open a PR against `yusufkaracaburun/ai-kit` adding both files. Every contributed case becomes a regression test the next release must pass. This is how ai-kit quality compounds at < 50 users: failures surfaced once stay fixed.

## Not this skill

- **Bug in ai-kit's installer / scripts** — file a `bug` issue via `gh issue create --template bug.yml`. Eval cases test skill *behaviour*, not script defects.
- **General feedback ("this felt clunky")** — use `/ai:feedback` instead. Eval cases are for concrete failures with a reproducible prompt and an articulable "what should have happened".
- **A skill the user has never invoked** — eval cases require a real prompt + actual output. If both are hypothetical, file as `skill-suggestion` so the design discussion happens first.

If the user's input matches one of the above, route them and stop.

## Process

### 1. Pick the target skill + scenario name

Ask the user (or infer from context):

- **Skill name** — exact dir name under `workflow/skills/`. Validate it exists: `gh api repos/yusufkaracaburun/ai-kit/contents/workflow/skills/<name>` returns 200.
- **Scenario name** — short kebab-case slug describing the case (e.g. `missing-package-json`, `concurrent-edit-conflict`). Reject duplicates: check `gh api repos/yusufkaracaburun/ai-kit/contents/tests/eval/prompts/<skill>/<scenario>.md` returns 404 before continuing.

### 2. Capture the three required pieces

Walk the user through these one at a time. Reject vague answers — eval cases die on vagueness.

- **The prompt** — exact text the user typed (or the orchestrator agent constructed) that triggered the skill. If the user paraphrases, ask for the verbatim string. The fixture file's value comes from here.
- **The actual output** — what the skill produced. Verbatim, including any tool calls the user saw. Truncate at ~200 lines max; long traces hide the signal.
- **What should have happened** — a bullet list (3–8 bullets). Each bullet is a behaviour the corrected skill must exhibit, written so it's testable from text matching. Examples:
  - "extracts at least one concrete file:line reference"
  - "routes to `/gsd-pause-work` when `.planning/` exists and gsd is installed"
  - "does NOT execute `/clear` itself"

If the user can't articulate the third piece, stop. An eval without an expected-behaviour list is a complaint, not a test. Route them to `/ai:feedback`.

### 3. Redact PII

Apply the same redaction rules as [`feedback`](../feedback/SKILL.md) to the prompt and actual-output blocks **before** writing files:

- Replace absolute paths under `/Users/<name>/...` or `/home/<name>/...` with `~/…`.
- Strip anything matching `(sk|pk|api|token|secret|password|bearer)[\s_-]*[:=][\s'"]*[A-Za-z0-9_\-+/]{16,}`.
- Replace tenant/customer/employer names with placeholders (`<tenant>`, `<customer-a>`). Ask the user to confirm the mapping if any specific name appears > once.
- Replace email addresses unless the user explicitly opts in to keeping them.
- Replace commit SHAs with `<sha-1>`, `<sha-2>` only if the user requests; SHAs alone are usually not sensitive and provide useful test signal.

Show the user the redacted prompt + actual-output side-by-side and confirm before writing anything.

### 4. Compose the prompt fixture

Write `tests/eval/prompts/<skill>/<scenario>.md` matching the existing format:

```yaml
---
id: <scenario>
skill: <skill>
expects:
  - <bullet 1 from step 2c>
  - <bullet 2 from step 2c>
  - <bullet N>
---

# Prompt

<redacted user prompt from step 2a>
```

Inspect any existing fixture (e.g. `tests/eval/prompts/checkpoint/before-clear.md`) for an example of the indentation and style — match it exactly.

### 5. Compose the golden rubric

Write `tests/eval/goldens/<skill>/<scenario>.md` with frontmatter the deterministic scorer (`bin/eval-golden.sh`) understands:

```yaml
---
id: <scenario>
skill: <skill>
required_headings: []        # markdown headings the corrected output must contain
required_keywords: []        # case-insensitive substring checks
required_phrases: []         # exact-case substring checks
forbidden_keywords: []       # text that signals a regression (TODO, placeholder, etc.)
min_lines: 0
max_lines: 9999
---

# Hand-written golden output for `<skill>` / `<scenario>`

<one-paragraph description of the case>

---

<the ideal response — the user writes this OR you derive a minimal one
from the actual output + their expected-behaviour bullets, then ask the
user to refine before publishing>
```

Derive the rubric fields from the user's expected-behaviour bullets:

- Each bullet that names a section ⇒ `required_headings` entry.
- Each bullet that names a noun the output must include ⇒ `required_keywords`.
- Each bullet that names a fixed phrase ("Checkpoint saved") ⇒ `required_phrases`.
- Each bullet that says "must NOT do X" ⇒ `forbidden_keywords`.

Conservative defaults: empty arrays unless the user named the exact strings. False-positive failures erode trust in the suite faster than missing tests do.

### 6. Validate locally before publishing

If the user is running the skill in a clone of ai-kit (check via `gh api ...` not returning early), ask them to run:

```bash
bash bin/eval-golden.sh --validate-all
```

`--validate-all` runs every golden against its own rubric. The new case should pass — if it fails, the rubric is internally inconsistent and needs refinement before the PR opens.

If the user is running in another repo (the normal case), skip this step and note that CI will validate on PR open.

### 7. Open the PR

Branch name: `eval/<skill>-<scenario>` off `master`.

Files to commit:

- `tests/eval/prompts/<skill>/<scenario>.md`
- `tests/eval/goldens/<skill>/<scenario>.md`

Commit message:

```
test(eval): add <skill>/<scenario> regression case

Captures <one-line description of the failure>.

Closes: <link to /ai:feedback issue if one exists, else "—">
```

PR title: `eval: add <skill>/<scenario> regression case`

PR body must include:

- One-paragraph summary of the failure being captured.
- Link to the originating `/ai:feedback` issue if one exists.
- The expected-behaviour bullets from step 2c.
- A checkbox confirming redaction (paths, emails, secrets, tenant names).

Show the user the full PR body before running `gh pr create`. After publish, print the PR URL.

## Hard rules

- **Never publish without preview.** Both files + the full PR body get shown before any `gh` write call.
- **No vague rubrics.** `required_keywords` must come from the user's stated expectations, not the model's guesses. Empty is fine; invented is not.
- **One case per PR.** Three failures = three PRs. Easier to review, easier to revert.
- **PII stays in the user's machine.** Even if redaction looks fine, ask the user to scan the rendered diff one more time before they hit publish.
- **Eval is for behaviour, not implementation.** Don't add `required_phrases` that pin internal wording — that turns the suite into a snapshot test and breaks on every reword.

## Why this exists

ai-kit at < 50 users has no telemetry pipeline. The quality loop is GitHub + this skill plus `/ai:feedback`. Feedback issues capture *that* something is wrong; eval contributions capture *what* would have been right and lock the fix into CI. The two skills are a pair: `/ai:feedback` → triage → `/ai:contribute-eval` → PR → CI gate.

## See also

- [`feedback`](../feedback/SKILL.md) — file the originating friction first; cite the issue from the eval PR.
- [`tdd`](../tdd/SKILL.md) — same red/green discipline, applied to skill outputs instead of code.
- [`triage`](../triage/SKILL.md) — what happens to feedback issues that become eval-worthy.
- `bin/eval-golden.sh` — the deterministic scorer that runs every contributed rubric.
