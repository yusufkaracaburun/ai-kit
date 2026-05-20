---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Use when context is getting full, before /clear, or when handing work to another machine or teammate.
argument-hint: "What will the next session be used for?"
---

Write a handoff document so a fresh agent can continue the work. Save it to the OS temp directory (`$TMPDIR` on macOS, `/tmp` on Linux) — never inside the user's project.

If the user passed arguments, treat them as the focus of the next session and tailor the document accordingly.

## Process

1. **Locate prior artifacts.** Identify PRDs, plans, ADRs, issues, commits, and diffs that already capture parts of the work. The handoff must *reference* these by path or URL, never duplicate their content. Duplication rots fast.
2. **Pick the temp path.** Use `$(mktemp "${TMPDIR:-/tmp}/handoff-XXXXXX.md")` so two parallel handoffs don't collide.
3. **Fill the template below.** Skip sections that don't apply rather than padding with "n/a".
4. **Redact.** Strip secrets, tokens, absolute paths under `/Users/<name>` or `/home/<name>` (use `~/` or a placeholder), and PII. Also strip stack traces that contain machine-specific paths.
5. **Suggest the next skills.** Be specific: which skill to invoke and why. The receiving agent will not have your conversation history.
6. **Print the path.** Show the user the full path so they can copy or move it.

## Template

```markdown
# Handoff: <one-line focus>

**Created:** <ISO date> · **From:** <project name or repo>
**Next session focus:** <user-provided argument or your best guess>

## State right now

- What is done, in 3-5 bullets. Reference commits/PRs by hash or number, not by re-explaining.
- What is in-progress, with the exact file/function/line if mid-edit.
- What is blocked and on whom.

## Open questions

- Numbered list. Each question should be answerable in one decision.
- Mark questions the receiving agent can answer themselves vs. ones that need the user.

## Where the truth lives

- PRD: `docs/prd/feature-x.md`
- Plan: `.planning/.../PLAN.md`
- ADRs touched: `docs/adr/000N-*.md`
- Recent commits: `<sha>..<sha>`
- Failing tests: paste output once, link the file.

## Suggested skills for the next session

- `skill-name` — why it fits
- ...

## Do NOT

- Specific footguns the receiving agent should avoid (e.g. "don't run the seed script — it drops the dev DB").
- Approaches already ruled out, with a one-line reason.
```

## What NOT to put in a handoff

- **Verbatim copies of the PRD/plan/ADR.** Link them. If the doc moves, the handoff stays correct because it references by path.
- **Decision rationale that already lives in an ADR.** Reference the ADR number.
- **The full diff.** Reference the commit range; the next agent will `git show` it themselves.
- **Step-by-step instructions for trivial commands** the next agent can derive (e.g. "run `pnpm install`"). Include only commands that are non-obvious or where order matters.
- **Conversation transcript.** The handoff is the distillation, not the log.
- **Secrets, API keys, tokens, full file paths under the user's home, or anything that would embarrass someone if leaked.** If you're unsure, redact.
- **Wishful thinking.** "Should be quick" / "minor fix" are tells that the previous session under-investigated. Be honest about uncertainty.

## Routing on the receiving end

A good handoff sets up `/resume-work` or an equivalent rehydration step. If the receiving session is going to a different agent tool (e.g. Cursor → Claude Code), call that out explicitly so the next session knows which conventions apply.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" handoff start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" handoff done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

