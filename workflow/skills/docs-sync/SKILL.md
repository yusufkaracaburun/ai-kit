---
name: docs-sync
description: "Content-drift checks for the current project — dead markdown links today; repo-hygiene + finished-work cleanup added in follow-up issues. Standalone counterpart to /ai:hygiene (install + catalog health). Use when wrapping up a session, after a rename or refactor, before opening a PR, or on 'check docs', 'are the links still good', 'is anything stale'. Reports only; never auto-edits files."
allowed-tools: Bash
---

# /ai:docs-sync

Standalone content-drift surface for ai-kit. Stays focused on *content correctness* — install + catalog health live in `/ai:hygiene`.

## How it runs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-docs-sync.sh" [path] [--skip-dead-links] [--no-prompt]
```

The driver runs each section in order, prints a per-section header, and exits with the max section exit code (`0 clean` / `1 findings`).

`--no-prompt` is automatic when stdin is not a TTY (CI, eval framework, pipes).

## Sections

### finished-work — local merged branches / closable issues

Two sub-checks, both read-only by default:

1. **Local merged branches.** `git branch --merged <default>`. Default branch detected via `git remote show origin` HEAD, falling back to `master` then `main`. The default branch itself, `HEAD`, and the currently-checked-out branch are always excluded.
2. **Closable issues.** For each recently merged PR (`gh pr list --state merged --limit 50`), extract `closes #N` / `fixes #N` / `resolves #N` from the body via strict regex (case-insensitive verb, NO fuzzy match for `addresses #N` / `see #N` / `for #N`). If the referenced issue is still `OPEN`, it counts as closable.

Fix flow (strictest guardrails per #88 — destructive + visible to others):

- **Local branch delete** → group-confirmable: `git branch -d <name>` per branch. `-d` refuses to delete unmerged branches as a safety net.
- **Remote branch delete** → **always individual y/N per branch**: `git push origin --delete <name>`. There is no batch flag.
- **`gh issue close`** → **always individual y/N per issue**, with the issue title + closing PR URL printed inline. There is no batch flag.

Skips cleanly when the project is not a git repo, when no default branch can be detected, or when `gh` is unavailable / unauthenticated (closable-issues sub-check warns + skips, merged-branch sub-check still runs).

### repo-hygiene — empty dirs / broken symlinks / orphan skill dirs

Three mechanical sub-checks, all `find`-based:

1. **Empty directories.** Excludes `.git`, `node_modules`, `vendor`, `.tmp`, `dist`, `build`, `.next`, `.turbo`, `.cache`.
2. **Broken symlinks.** Detected portably (works on both GNU find and macOS/BSD find).
3. **Orphan `.agents/skills/<name>/` dirs.** Skill dir without a `SKILL.md`. **Report-only** — never auto-deleted, because the dir may be in-progress work.

Fix flow (per #88 grilling, two-step with destructive guardrails):

- Empty dirs + broken symlinks → **group-confirmable** single y/N prompt: `Fix N safe item(s) now (rmdir empty dirs + rm broken symlinks)?`. Accept = `rmdir` / `rm` each. Decline = nothing happens.
- Orphan skill dirs → no fix prompt **ever**. The "skill scaffold without SKILL.md" pattern is how in-progress skills look; deleting them is dangerous.

### dead-links — markdown link integrity

Scans every `*.md` file in the project for inline markdown links `[text](path)`. For each link:

- External schemes (`http:`, `https:`, `mailto:`, `tel:`, `ftp:`, etc.) → skipped (not docs-sync scope).
- Pure anchor (`#section`) or empty target → skipped.
- Relative path → resolved against the markdown file's directory.
- Repo-absolute path (`/foo`) → resolved against the project root.
- Anchor + query string suffixes are stripped before the path-exists check.

Code fences (` ``` `, `~~~`) are skipped — links inside code blocks are illustrative, not navigable.

When findings exist, the script prints `file:line` + the offending link + the missing resolved path, then offers an opt-in fix-suggestion prompt. Suggestions are advisory only — `/ai:docs-sync` **never** auto-edits markdown files.

## Non-goals

`/ai:docs-sync` is intentionally narrow. Future contributions MUST NOT add:

1. **ADR-trigger detection.** Picking up "this commit needs an ADR" requires project-specific keyword lists (Laravel migrations, Spatie permissions, etc.). Stays project-local in repo-specific docs-sync skills.
2. **TODO-completion detection.** TODOs format wildly across projects (checkboxes, GH issues, `// TODO`, `docs/todos/`). Too noisy for the framework layer.
3. **Status-table drift.** Assumes a specific table format + specific enum source. Project-local.
4. **Persona / PII grep.** Demo/real-name wordlists are per-project; framework can't know what counts as "real" vs "demo".
5. **Structure-convention checks.** `docs/README.md` as authoritative index is one project's convention, not universal.
6. **Code-comment-as-doc parsing.** The graph stays inside `docs/` + `*.md` files; framework never reaches into source comments.

Scope-bounds for v1's checks:

- **Dead links.** Inline `[text](path)` only. No HTML `<a href>`. No bare URLs (link-rot belongs to a different tool). No anchor (`#section`) validation. No reference-style links.
- *(Future)* Repo-hygiene = `find`-based mechanical checks only. No AST. No dead-code detection.
- *(Future)* Finished-work cleanup = `--merged master/main` branches only, strict `closes #N / fixes #N / resolves #N` regex for issue close-candidates. No fuzzy matching.

## Working with project-local docs-sync skills

A repo may keep its own `.agents/skills/docs-sync/` skill that handles project-specific drift (ADR triggers, persona names, status tables). Both surfaces are valid and complementary:

- `/docs-sync` (project) — repo-specific drift; runs in the project's own vocabulary.
- `/ai:docs-sync` (framework) — universal drift; same shape across every project.

`/ai:hygiene` surfaces both when applicable, with a one-line "use this for X" hint.

## Output shape

```
=== dead-links (markdown link integrity) ===
dead-links: 2 broken link(s) found:

  docs/architecture.md:42
    [setup guide]( ../EXAMPLE-RENAMED-FILE ) → missing path: EXAMPLE-RENAMED-FILE
  docs/glossary.md:118
    [legacy install]( legacy-doc ) → missing path: docs/legacy-doc

=== summary ===
docs-sync: findings reported (exit 1).
```

When clean:

```
=== dead-links (markdown link integrity) ===
dead-links: 0 broken links across 47 markdown files — clean.

=== summary ===
docs-sync: all sections clean.
```
