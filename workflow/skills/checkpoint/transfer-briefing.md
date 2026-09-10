# Transfer briefing (for /ai:checkpoint --to tmp)

Full procedure for `--to tmp`. This path replaces §2-§7 of `SKILL.md` entirely:
write a transfer briefing for another agent, machine, or teammate — no
MEMORY.md update, no docs-sync nudge, no GSD routing.

## 1. Locate prior artefacts

Identify PRDs, plans, ADRs, issues, commits, and diffs that already capture
parts of the work. The briefing *references* these by path or URL, never
duplicates their content. Duplication rots fast.

## 2. Pick the temp path

```bash
mktemp "${TMPDIR:-/tmp}/handoff-XXXXXX.md"
```

Two parallel briefings won't collide. The historic filename prefix
`handoff-` is preserved so existing tooling and muscle memory still work.

## 3. Write the briefing

```markdown
# Handoff: <one-line focus>

**Created:** <ISO date> · **From:** <project name or repo>
**Next session focus:** <user-provided slug, or your best guess>

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

## Do NOT

- Specific footguns (e.g. "don't run the seed script — it drops the dev DB").
- Approaches already ruled out, with a one-line reason.
```

Skip sections that don't apply rather than padding with "n/a".

## 4. Redact (always-on for `--to tmp`)

Strip:
- Secrets, tokens, API keys, passwords.
- Absolute paths under `/Users/<name>` or `/home/<name>` — use `~/` or a placeholder.
- PII (email addresses, full names not already on the project).
- Stack traces that contain machine-specific paths.

If you are unsure whether something is sensitive, redact. The briefing
crosses the machine boundary; treat it as if it might be pasted into a chat.

## 5. What NOT to put in the briefing

- Verbatim copies of the PRD/plan/ADR — link them.
- Decision rationale that already lives in an ADR — reference the ADR number.
- The full diff — reference the commit range.
- Step-by-step instructions for trivial commands the next agent can derive
  (e.g. "run `pnpm install`"). Include only commands that are non-obvious
  or where order matters.
- Conversation transcript — the briefing is the distillation, not the log.
- Wishful thinking. "Should be quick" / "minor fix" are tells that the
  previous session under-investigated. Be honest about uncertainty.

## 6. Self-check before confirming

- The body contains at least `## State right now` AND `## Open questions`.
- Total body bullets across all sections ≥ 3.
- At least one concrete reference: a commit SHA, a file path with
  extension, an issue/PR number, or an ADR reference.
- A "Suggested skills" line names at least one slash command the receiving
  agent can run.

## 7. Print the path

Show the user the full path so they can copy or move it:

```
Handoff briefing saved → /var/folders/.../handoff-AbC123.md
Suggested next skill on the receiving end: /ai:onboard (project shape) or
re-load this file's "Suggested skills" line.
```

In `--mid-session` mode: same briefing, same path. Add "Continue in this
session — focus on the next 1-3 items from State/Open; the briefing exists
in case the session ends abruptly." Do NOT suggest /clear.
