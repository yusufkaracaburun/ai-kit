---
name: rename-housekeeping
description: Rewrite stale absolute-path references in memory files after a local repo rename or move. Scans `~/.claude/**`, project `CLAUDE.md`/`AGENTS.md`/`.agents/memory/**`/`.planning/**`/`docs/**`/`.claude/**`, and `~/.cursor`/`~/.codex`/`~/.gemini`. Snapshots writes to `~/.claude/.backups/<ts>/` first. Use when user says "I renamed the repo", "moved this project", "verplaatst", "hernoemd", "fix stale paths", or invokes `/ai:rename-housekeeping <old> <new>`.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
argument-hint: "<old-basename-or-path> <new-basename-or-path>"
---

# Rename housekeeping

Repo gets renamed (`mv school-activities-hub naschool`) or moved (`mv ~/projects/foo ~/Sites/foo`). Memory files still reference the old absolute path or basename. Next session copy-pastes stale `cd` commands → hits non-existent dir → user pays round-trip + correction.

This skill rewrites every stale reference in the detector universe, with dry-run preview + per-file confirm + backups.

## Args

```
/ai:rename-housekeeping <old> <new>
```

- `<old>` — old basename (`school-activities-hub`) OR old absolute path (`/Users/y/Sites/localhost/school-activities-hub`).
- `<new>` — new equivalent. If `<old>` is a basename, `<new>` must also be a basename. If `<old>` is an absolute path, `<new>` must also be a path.

If args missing, ask via AskUserQuestion. If user just said "I renamed X to Y" in chat without invoking the slash, parse from context and confirm.

## Detector universe

Scan for old basename + old absolute path in:

| Scope | Glob |
| ----- | ---- |
| User-global | `~/.claude/CLAUDE.md` |
| User-global | `~/.claude/*.md` (siblings: `ai-kit-lessons.md`, `rules/*.md`) |
| User-global | `~/.claude/rules/**/*.md` |
| Per-project memory | `~/.claude/projects/<slug>/memory/**/*.md` |
| Project root | `<repo>/CLAUDE.md` |
| Project root | `<repo>/AGENTS.md` |
| Project | `<repo>/.agents/memory/**/*.md` |
| Project | `<repo>/.planning/**/*.md` |
| Project | `<repo>/docs/**/*.md` |
| Project | `<repo>/.claude/**/*.md` |
| Cross-agent | `~/.cursor/**/*.md` |
| Cross-agent | `~/.codex/**/*.md` |
| Cross-agent | `~/.gemini/**/*.md` |

Files larger than 1 MB or matching `node_modules/`, `vendor/`, `.git/` are skipped.

## State store

```
~/.claude/known-projects.json
```

Schema:

```json
{
  "projects": [
    {
      "name": "naschool",
      "path": "/Users/y/Sites/localhost/naschool",
      "first_seen": "2026-05-20",
      "last_seen": "2026-05-25"
    }
  ]
}
```

Written by the SessionStart hook (`bin/hooks/rename-detector.sh`) and rewritten by this skill on successful apply.

## Process

All deterministic work is delegated to `bin/rename-housekeeping-core.sh` so it is testable without an LLM in the loop. This skill orchestrates the user interaction.

1. **Validate args.** If `<old>` looks like a path → `<new>` must also be a path. Both must be non-empty + different.
2. **Scan.** Invoke `bash "$AI_KIT_ROOT/bin/rename-housekeeping-core.sh" scan "$OLD" "$NEW"`. Output is `<file>\t<lineno>:<line>` per hit. Exit 1 = no hits → tell user "nothing to rewrite" and stop.
3. **Build preview table.**

   ```
   file                                            line   match
   --------------------------------------------------------------
   ~/.claude/CLAUDE.md                              42    cd /Users/y/Sites/localhost/school-activities-hub
   ~/.claude/projects/-xyz/memory/foo.md            17    school-activities-hub
   <repo>/.planning/phases/14/SUMMARY.md            12    /school-activities-hub/backend
   ```

4. **Confirm.** `AskUserQuestion` — `apply all` / `abort`. (Subset selection is out of scope for v1 — all-or-nothing keeps the core deterministic.)
5. **Apply.** Invoke `bash "$AI_KIT_ROOT/bin/rename-housekeeping-core.sh" apply "$OLD" "$NEW"`. The core script:
   - snapshots every `~/.claude/**` target to `~/.claude/.backups/<YYYYMMDDTHHMMSSZ>/` before write
   - replaces every literal occurrence of `<old>` with `<new>` via a python utf-8 helper (no regex escaping)
   - updates matching `known-projects.json` entries (`path`, `name`, `last_seen`)
   - prints a 2-line summary (`modified: N files`, `backups: M files in <dir>`)
6. **Report** the core script's summary to the user verbatim.

   ```
   modified: N files, M replacements
   backups : ~/.claude/.backups/<timestamp>/ (K files)
   state   : known-projects.json updated for "<name>"
   ```

## Multi-clone guard (hook-side)

The SessionStart hook (`rename-detector.sh`) MUST NOT fire a rename suspicion when both old and new paths exist on disk — that's two clones, not a rename. The hook's check:

```
basename($PWD) == known.name
  && $PWD != known.path
  && ! test -d known.path     # OLD path GONE → real rename
```

This skill does not consult the hook state at runtime; it acts on whatever `<old>` / `<new>` the user passes. Multi-clone safety is the hook's job, not the skill's.

## Out of scope (locked)

- `@-import` recursion across non-default import paths
- Pre-write validator that catches paths LLM *introduces* (own issue)
- Semantic gsd → ai-kit `.planning/` migration (string-match only)
- Symlink-flip detection (mv-rename only)
- Auto-apply without confirm
- Cross-machine sync of `known-projects.json`
- CI / GH Actions integration

## Trust model

- **Never widen scope.** If scan finds `<old>` matches in source code (`.php`, `.ts`, etc.), still rewrite — but flag those in the preview table with a `code:` prefix so user sees them before confirming.
- **Never delete the backup dir.** Backups persist; user purges manually.
- **Never write outside the detector universe.** No edits to `.git/`, no edits to binary files.
- **Always preview before write.** Even with `--yes` (not supported).

## Usage logging (opt-in)

```bash
[ "${AI_KIT_USAGE:-}" = "1" ] && bash "$AI_KIT_ROOT/bin/log-skill.sh" rename-housekeeping start
# … work …
[ "${AI_KIT_USAGE:-}" = "1" ] && bash "$AI_KIT_ROOT/bin/log-skill.sh" rename-housekeeping done
```

## Related

- Core: `bin/rename-housekeeping-core.sh` — scan/apply engine (tested directly)
- Hook: `bin/hooks/rename-detector.sh` — SessionStart detector
- Installer: `bin/install-rename-hook.sh` — wires hook into `~/.claude/`
- Lesson: `~/.claude/ai-kit-lessons.md` "2026-05-23 — Repo rename leaves stale path refs"
