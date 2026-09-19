# ADR-0015: Universal rules ship through the global channel (`~/.claude/rules/ai-kit`)

## Status

Accepted 2026-09-19 (grilled, #171). Supersedes the decision in ADR-0011;
amends ADR-0012 (`global_channel_available` now also decides where rules
live). Closes #171, #149.

## Context

Three of the five ai-kit-marked repos on this machine (planny, emeq/system,
theorieplek) load **zero** universal rules: their owner reverted the 58
files `/ai:setup` wrote ("we hebben ai-kit toch global geïnstalleerd").
The other two (emeq-hub 28, planny-app-mobile 25) carry per-repo copies
that never receive a new universal rule (#149). Cursor rules: none, in any
repo.

Measured today with the #182 headless-sentinel method: Claude Code loads
`~/.claude/rules/**/*.md` natively for every project on the machine — a
file without `paths:` at session start, a file with `paths:` on first
touch of a matching file, symlinked directories included. That is the
global channel ADR-0012 named, as a rule loader. Plugin content lives in
`~/.claude/plugins/cache/yusufkaracaburun/ai/<version>/`, so the path
moves every release.

Catalog: 17 universal always-on pathless rules (5,239 words) + 6 universal
`paths:`-scoped (2,304 words) + 15 stack rules (`universal: false`, all
`paths:`-scoped).

## Decision

1. **All 23 universal always-on rules are global.** The plugin ships them pre-emitted
   (same Claude Code emitter, checked in, CI drift-tested like emitted
   agents). The plugin `SessionStart` hook keeps
   `~/.claude/rules/ai-kit → $CLAUDE_PLUGIN_ROOT/rules` current with one
   idempotent `ln -sfn`; one-session lag after a plugin update, then
   correct. `/ai:doctor` reports the link (present / stale / opt-out).
   Opt-out: `~/.config/ai-kit/no-global-rules` marker, same pattern as the
   other machine-wide toggles.
2. **Per-repo `.claude/rules/` = stack rules only**, the ones
   `recommend-rules` detects, `paths:`-scoped. Universal rules are emitted
   per repo only when `global_channel_available=false` (project-only
   install without the plugin). Cursor, when `.cursor/` exists *before*
   bootstrap runs, still gets the full set as `.mdc` — no global channel
   there.
3. **Docs scaffold becomes a recorded setup choice** (`docs_scaffold`
   marker field): default no when brownfield, yes greenfield;
   `verify-setup` gates on it like `domain_docs`.
4. **`/ai:upgrade` removes generated universal copies** from a repo's
   `.claude/rules/` once the global channel serves them (only files with
   the ai-kit header; hand-written rules untouched). Doctor WARNs "loaded
   twice" until then.
5. `bin/hooks/session-rules-inject.sh`, `bin/ai-kit-no-rule-injection.sh`
   and their tests are deleted. ADR-0011 kept them as a fallback for "a
   host stops loading `.claude/rules/` natively"; that host would drop
   `~/.claude/rules/` too, and the whole project-rules concept with it —
   not a case worth 200 lines of unwired code.
6. Subagents: the four rule-reading agents (`builder`, `designer`,
   `reviewer`, `verifier`) read `~/.claude/rules/ai-kit/` alongside
   `.claude/rules/`; whether the host delivers user-level rules to
   subagents is probed at implementation and recorded in
   `reference_subagent_context_delivery`.

## Options rejected

- **Plugin `SessionStart` hook injects rule text as `additionalContext`**
  (the #171 memo plan, ADR-0011's option 1). Gate-able per repo, but 200
  lines of custom loader where the host has a native one, and the injected
  text is invisible to the host's own rule accounting. Only wins if some
  repo on this machine must *not* see ai-kit rules; none does.
- **Stack rules global too** (per-repo emit → nothing). Zero cost until
  touched, but 15 stack globs overlap (`tailwind` on any `.tsx`, `sql-style`
  on every migration) and a project loses the choice to skip one. The
  remaining per-repo set is 3–6 files.
- **Report-only migration.** #149's "melden boven schrijven" was about
  writing unrequested files, not removing ai-kit's own header-marked ones
  at an explicit `/ai:upgrade`.

## Consequences

- Every Claude Code session on the machine pays ≈7k tokens for the 17
  pathless universal rules — same class as the global `CLAUDE.md`. Two
  rules assume an `.ai-kit-setup` marker (`project-lifecycle`,
  `phase-scope-discipline`) and degrade to the development default without
  one.
- #149 drift is gone for universal rules (a plugin update *is* the rule
  update). Stack-rule drift stays doctor-reportable (emitted set vs
  `recommend-rules`), WARN only.
- Two releases: first the global channel (plugin `rules/`, hook link,
  doctor check, opt-out) so downstream repos can confirm loading; then
  setup/bootstrap (stack-only emit, docs question, `detect-tooling`
  recognising the ai-kit header, upgrade removal).
- `context-lean` reports the global set as one line, not per project.
