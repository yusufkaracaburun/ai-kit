# ADR-0010: Add GitHub Copilot as a rules-only host

## Status

**Rejected** (2026-07-09)

Proposed as an amendment to [ADR-0006](0006-scope-claude-code-cursor-only.md),
then rejected the same day. ADR-0006 stands unchanged: ai-kit targets **Claude
Code and Cursor** only.

Kept as a record so the question is not re-derived. The investigation below is
the reason, not a summary of one.

## Context

The maintainer raised using ai-kit from GitHub Copilot alongside Claude Code and
Cursor. Copilot's customisation model is a different shape, so this was a scope
decision rather than a wiring change.

**What Copilot consumes** (verified 2026-07-09 against `docs.github.com/en/copilot`):

| Artefact | Location | Availability |
| --- | --- | --- |
| `copilot-instructions.md` | `.github/` | every surface, incl. Xcode / Eclipse |
| `<name>.instructions.md` | `.github/instructions/` | supports `applyTo` glob, `excludeAgent` |
| `AGENTS.md` / `CLAUDE.md` | repo root | "not supported by all Copilot features" |
| `<name>.prompt.md` | workspace | VS Code, Visual Studio, JetBrains |

Copilot has **no `SKILL.md` primitive**. The docs never mention it.

**What ai-kit's rules carry:** 30 canonical rules in `standards/rules/*.mini.md`,
14 marked `universal: true`. Frontmatter has `applies_to.{frameworks,languages,
architectures}`, `default_mode`, `weight` — and **no file-glob metadata**. The
Cursor emitter already emits an empty `globs:` field for that reason
(`bin/lib/emitters/cursor.sh`).

## Decision

**Do not add Copilot.** ai-kit stays scoped to Claude Code and Cursor.

Two findings collapsed the value of the proposal to near zero:

1. **Skills do not port.** Skills are ai-kit's largest surface (38) and its
   highest-leverage one, because Claude Code and Cursor both auto-route to a
   skill from its `description`. Copilot's nearest artefact, `*.prompt.md`, is
   user-invoked. Porting the lifecycle would produce 38 files nobody calls,
   because nothing routes to them.

2. **Rules port, but degenerately.** Copilot's `applyTo` takes a file glob. No
   ai-kit rule has one. Every emitted `.instructions.md` would therefore carry
   `applyTo: "**"` — behaviourally identical to a single flat
   `.github/copilot-instructions.md`, spread across 30 files.

So the honest Copilot offering was one concatenated instructions file: the rule
corpus, flattened, with no routing and no skills. That is a fraction of the kit,
and it is a third code path to maintain. ADR-0006 deleted four emitters
precisely because untested-in-practice paths are a maintenance liability.

`AGENTS.md` already exists in ai-kit projects for other reasons, and Copilot
reads it where supported. A Copilot user therefore already gets the repo-level
context for free, with zero ai-kit work. That was the only part worth having.

## Consequences

- ai-kit remains pure Bash + Markdown with two exercised hosts. No third
  emitter, no third code path, no README asterisk explaining that one host gets
  half the product.
- A Copilot user in an ai-kit repo picks up `AGENTS.md` and nothing else. To use
  the lifecycle they open the same repo in Claude Code or Cursor.
- **Reopen only if** ai-kit rules gain file-glob metadata *and* Copilot ships a
  description-routed skill primitive. Either alone is insufficient: globs
  without routing still leaves the lifecycle behind; routing without globs still
  leaves the rules flat.
