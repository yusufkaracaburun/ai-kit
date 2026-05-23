---
name: feedback
description: Send structured feedback about ai-kit itself — friction, surprise, clarity, gaps, or wins — to the ai-kit GitHub repo. Use when user says "this skill was annoying", "ai-kit should also do X", "report this to ai-kit", "give feedback on ai-kit", "/ai:feedback", or any variant of "this kit could be better at …".
---

# Send feedback to ai-kit

Capture one structured piece of feedback from the user about ai-kit — friction, surprise, clarity, gap, or win — and open a GitHub issue against `yusufkaracaburun/ai-kit` using the **feedback** issue template. This is how ai-kit improves at < 50 users: real friction, surfaced cheaply, triaged in the open.

## Not this skill

- **Bug in ai-kit** — use the `bug` template directly via `gh issue create --repo yusufkaracaburun/ai-kit -t bug`. Bugs are reproducible defects; feedback is everything else.
- **Propose a new skill** — use the `skill-suggestion` template. Specific design proposal, not "I wish there was …".
- **Question or open-ended discussion** — point the user at https://github.com/yusufkaracaburun/ai-kit/discussions instead of opening an issue.
- **Bug in the user's own project** — out of scope. `/ai:feedback` is feedback about ai-kit, not the project being built with it.

If the user's input clearly matches one of the above, route them and stop.

## Process

### 1. Detect the kind

Ask the user one question to pick one of:

- **Friction** — the skill/rule worked but felt clunky (too many turns, too much output, weird default).
- **Surprise** — behaviour differed from what the description led the user to expect.
- **Clarity** — docs / skill description / output was unclear.
- **Gap** — a real situation isn't covered by any current skill/rule.
- **Win** — what worked well (file this so we don't regress it).

Skip the question if the user already stated the kind plainly ("this was confusing" → Clarity; "I wish ai-kit also covered X" → Gap).

### 2. Gather the three required fields

Walk the user through these one at a time, terse:

- **Situation** — one paragraph: what were they trying to do?
- **Friction** — specific, observable. Reject vague answers ("slow", "bad") and ask for the concrete moment ("on turn 3 the skill re-read the same file"). Specific complaints fix; vague complaints rot.
- **Better** — optional. The experience they wanted. Implementation-agnostic is fine.

### 3. Offer to attach context

Offer to include the last 5 skill invocations from `~/.claude/cache/skill-log.jsonl` (or the equivalent — check the path on the host) as an anonymized context block.

**Before pasting, run redaction:**

- Replace absolute paths under `/Users/<name>/...` or `/home/<name>/...` with `~/…`.
- Strip anything matching common secret patterns: `(sk|pk|api|token|secret|password|bearer)[\s_-]*[:=][\s'"]*[A-Za-z0-9_\-+/]{16,}`.
- Strip repo names and email addresses unless the user explicitly opts in to including them.

Show the redacted block to the user **before** publishing. If anything still looks sensitive, drop it.

The user opts in per submit. Default = include context. If they say "no context", skip the block.

### 4. Detect ai-kit version

Try, in order:

1. `gh api repos/yusufkaracaburun/ai-kit/contents/VERSION --jq .content | base64 -d` (always-fresh canonical).
2. Plugin-cache `cat "${CLAUDE_PLUGIN_ROOT}/../../VERSION"` if `CLAUDE_PLUGIN_ROOT` resolves.
3. Ask the user for `/ai:doctor`'s reported version.

Use the first that succeeds. Never fabricate.

### 5. Compose + publish

Construct the issue with `gh issue create --repo yusufkaracaburun/ai-kit --template feedback.yml` (or via `gh api` if `--template` isn't supported in the user's `gh` version — fall back to `gh issue create` with `--title` and `--body` filled per the template structure).

Body fields the template expects (see `.github/ISSUE_TEMPLATE/feedback.yml`):

- `version` — from step 4
- `kind` — from step 1
- `area` — multi-select; derive from the situation if obvious, else ask
- `situation`, `friction`, `better` — from step 2
- `context` — optional, from step 3

Title prefix is `feedback:` (the template enforces this).

### 6. Show the user the URL

After `gh issue create` returns, print the issue URL and ask the user if they want to:

- **Watch** — `gh issue subscribe <num>` so they get triage updates.
- **Close** — they changed their mind; nothing was published if step 5 didn't run, otherwise offer `gh issue close`.
- **Stop** — default.

## Hard rules

- Never publish without showing the user the final body first. One-shot publishes lose trust.
- Never include unredacted absolute paths, email addresses, or secrets — even if the user pastes them. Redact, confirm, then publish.
- Never invent context. If the skill-log file doesn't exist, say so and submit without context.
- One issue per invocation. If the user has three pieces of feedback, file three issues.

## Why this exists

ai-kit at < 50 users has no telemetry pipeline. The feedback loop is GitHub + this skill. Every published feedback issue compounds — they get triaged via `/ai:triage`, the strong ones become `/ai:to-prd` PRDs, the rest get closed with reasoning. Friction surfaced this way costs ~30 seconds for the user and produces durable, public reasoning.

## See also

- [`triage`](../triage/SKILL.md) — what happens to feedback issues after they land.
- [`to-prd`](../to-prd/SKILL.md) — turning a strong feedback theme into a tracked PRD.
