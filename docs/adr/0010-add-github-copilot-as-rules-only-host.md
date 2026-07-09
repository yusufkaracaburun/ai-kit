# ADR-0010: Add GitHub Copilot as a rules-only host

## Status

Proposed

Amends [ADR-0006](0006-scope-claude-code-cursor-only.md), which scoped ai-kit
to Claude Code and Cursor and predicted: *"A future need to support another
host means re-introducing an emitter."* This is that need.

## Context

The maintainer wants to use ai-kit from GitHub Copilot in addition to Claude
Code and Cursor. Copilot's customisation model is not the same shape as the
other two hosts, so "add Copilot" is a scope decision, not a wiring change.

**What the vendor docs establish** (verified 2026-07-09 against
`docs.github.com/en/copilot`):

| Artefact | Location | Availability |
| --- | --- | --- |
| `copilot-instructions.md` | `.github/` | every surface, incl. Xcode / Eclipse |
| `<name>.instructions.md` | `.github/instructions/` | supports `applyTo` glob, `excludeAgent` |
| `AGENTS.md` / `CLAUDE.md` | repo root | "not supported by all Copilot features" |
| `<name>.prompt.md` | workspace | VS Code, Visual Studio, JetBrains |

Copilot has **no `SKILL.md` primitive**. The docs never mention it. Skills are
ai-kit's largest surface (38) and its highest-leverage one, because Claude Code
and Cursor both auto-route to a skill from its `description`. Copilot has no
equivalent: `*.prompt.md` files are user-invoked, closer to a slash command.

**What ai-kit's own rules establish:**

- 30 canonical rules in `standards/rules/*.mini.md`, 14 marked `universal: true`.
- Rule frontmatter carries `applies_to.{frameworks,languages,architectures}`,
  `default_mode`, `weight`, `universal` — and **no file-glob metadata**. The
  Cursor emitter already emits an empty `globs:` field for this reason
  (`bin/lib/emitters/cursor.sh`).

That last fact decides the shape of the emitter. Copilot's `applyTo` takes a
file glob. With no glob data on any rule, every emitted `.instructions.md` would
carry `applyTo: "**"` — behaviourally identical to a single repo-wide
instructions file, but spread across 30 files.

## Decision

Add **GitHub Copilot as a third host, rules-only.**

### Emit

- A new `bin/lib/emitters/copilot.sh` implementing the existing emitter contract
  `emit_copilot(target, rule_path, rule_name, mode, aikit_version)`, sourced and
  dispatched from `bin/emit-rules.sh` exactly like `cursor` and `claude-code`.
- Output: **one** `.github/copilot-instructions.md`, containing the rules
  selected for the project. Not 30 files under `.github/instructions/`.
- `detect_agents()` gains Copilot detection (`.github/copilot-instructions.md`
  present, or `.vscode/` with the Copilot extension configured).

### Do not emit

- **Skills are not ported.** No `*.prompt.md` generation. Copilot cannot
  auto-route on a skill description, so 38 hand-invoked prompt files would be
  surface without the behaviour that makes a skill worth having. A Copilot user
  reaches ai-kit's lifecycle from Claude Code or Cursor, in the same repo.
- **Subagents, hooks, slash commands** — no Copilot analogue in scope.
- **`AGENTS.md`** — already emitted for other reasons; Copilot reads it where
  supported. No new work, and no reliance on it, since coverage is partial.

### Revisit trigger

If rules ever gain file-glob metadata, `.github/instructions/*.instructions.md`
with real `applyTo` globs becomes strictly better than one flat file, and this
decision should be reopened.

## Consequences

**Positive**

- Copilot users get ai-kit's rule corpus — the portable half of the kit — at the
  cost of one ~60-line emitter that reuses the existing contract and tests.
- The choice of one file over thirty means Copilot works on every surface,
  including Xcode and Eclipse, which read only `.github/copilot-instructions.md`.
- No new toolchain. Still pure Bash + Markdown, consistent with ADR-0006.

**Negative / trade-offs**

- ai-kit's value in Copilot is materially lower than in Claude Code or Cursor.
  Rules shape behaviour; skills *are* the lifecycle. This asymmetry is inherent
  to Copilot's model and should be stated plainly in the README rather than
  papered over.
- Third host, third code path. ADR-0006 removed four emitters precisely because
  nobody exercised them, and called untested-in-practice paths "a maintenance
  liability". That risk applies here in full.

**Anti-drift guard** (carried over from ADR-0006's reasoning)

This ADR is justified by *stated intent to use Copilot*, not by demonstrated
use. If no ai-kit-emitted `.github/copilot-instructions.md` exists in any
actively developed project six months after this lands, delete the emitter and
supersede this ADR. Adding a host is cheap; keeping a host nobody runs is what
ADR-0006 was written to prevent.
