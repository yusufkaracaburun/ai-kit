# ADR-0005: Adapt setup to brownfield monorepos — monorepo detection, Boost coexistence, context-drift hook

## Status

Accepted (Unreleased)

## Context

Evaluating ai-kit against a real target — a Laravel 13 monorepo (`backend/`
plus three frontends) running Laravel Boost — surfaced three gaps that would
make `/ai:setup` misbehave there:

1. **Monorepo blindness.** `detect-tooling.sh` inspects a single root.
   `detect_package_manager` and `detect_frameworks` read only
   `$root/composer.json` / `$root/package.json`; `detect_architecture` flags a
   monorepo only when `nx.json` exists. A repo whose manifests live in
   `backend/`, `admin/`, … and which uses no Nx is detected as having *no stack
   at all*.

2. **No notion of an externally-owned `AGENTS.md`.** Laravel Boost generates
   and *regenerates* `AGENTS.md` (the `<laravel-boost-guidelines>` block) on
   every `artisan boost:*` run. `agents-patch.sh` would happily patch such a
   file; Boost would silently overwrite the patch on its next run.

3. **No drift signal.** ai-kit centres `CONTEXT.md` and `docs/adr/`, but nothing
   reminds you when an edit makes the code diverge from them. `review` and
   `grill-with-docs` catch drift only when explicitly invoked. The target
   project had hand-rolled a Laravel-specific `docs-drift-check.sh` hook — a
   pattern worth generalising.

## Decision

### 1. Generic monorepo detection

New `detect_monorepo()` in `bin/lib/detect-lib.sh` scans depth-1 child
directories for a package manifest (`composer.json`, `package.json`, `go.mod`,
`pyproject.toml`, `Cargo.toml`). Two or more app dirs ⇒ monorepo.
`detect-tooling.sh --json` gains a top-level `monorepo: { detected, apps[] }`.
`architecture.monorepo` keeps its Nx-structural meaning unchanged — the
addition is non-breaking.

### 2. Never patch an externally-owned `AGENTS.md`

New `detect_boost()` reports `boost: { detected, managed_files[] }` — scanning
the root and app dirs for the `laravel/boost` composer package and for
`AGENTS.md` files carrying the `<laravel-boost-guidelines>` marker.
`patch_agents_section()` in `agents-patch.sh` now refuses to touch any file
containing that marker. The marker — not "is this a Laravel project" — is the
gate, so the guard stays correct for any tool that adopts the same convention.

### 3. A stack-agnostic context-drift hook

New `bin/hooks/context-drift-check.sh`: a `PostToolUse(Edit|Write|MultiEdit)`
hook that, after an edit, checks whether the file's repo-relative path is named
in `CONTEXT.md`, `CONTEXT-MAP.md`, or `docs/adr/*.md`, and if so emits an
`additionalContext` nudge to keep the doc in sync. Drift is defined as "you
changed code the docs name" — no framework-specific paths, unlike the target
project's original. It is deterministic shell (no LLM) and a silent no-op when
no such docs exist.

`bin/apply-context-drift-hook.sh` installs it into a target project: it copies
the script under `.claude/hooks/` (referenced via a portable
`${CLAUDE_PROJECT_DIR}` path, never an absolute ai-kit path) and merges a
`PostToolUse` entry into `.claude/settings.json` non-destructively and
idempotently.

Opt-in: ai-kit does not auto-wire it. `/ai:setup` offers it; the project
decides.

## Consequences

**Positive**

- `/ai:setup` produces a true picture of a non-Nx monorepo instead of
  reporting an empty repo.
- ai-kit and Boost — or any `<laravel-boost-guidelines>`-style generator —
  coexist without a clobber loop.
- A second hook ships, generalised from a real project's pattern while staying
  stack-agnostic — the constraint that keeps ai-kit portable.

**Negative / trade-offs**

- `detect_monorepo` does not yet recurse per-app to report each app's stack — it
  lists the app dirs and leaves per-app detection to a follow-up. Enough to stop
  the "no stack" failure; not yet a full per-app picture.
- `apply-context-drift-hook.sh` *copies* the hook script into the target rather
  than symlinking. The script is tiny and stable; `/ai:upgrade` can re-copy.
  Copying avoids baking an absolute ai-kit path into a committed `settings.json`.
- The drift hook matches with a fixed-string path test — it can miss a renamed
  reference or fire on a coincidental substring. It is a nudge, not a gate; a
  false positive costs one line of context.

**Follow-ups**

- Per-app stack detection inside `detect_monorepo` (frameworks, package manager,
  Laravel version per app).
- `/ai:setup` branch wiring: surface the context-drift hook and the
  Boost / monorepo findings in the brownfield flow.
