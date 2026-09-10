# ADR-0012: Decompose `setup_mode` into a fact, a boolean, and brownfield defaults

## Status

Accepted — phased rollout (dual-write starts now; enum deprecation is a
later phase, see Follow-ups). Supersedes ADR-0001.

## Context

ADR-0001 collapsed six setup modes to four by bolting two orthogonal
questions — "does a global channel exist" and "does the project also want
skills merged in" — onto one enum, plus forcing brownfield to ride
whichever of those two values applied to it (`agent-stack-guide.md:20`:
`brownfield` has the identical `install-global: usually yes` /
`--merge-skills` row as `solo-both`). ADR-0001 itself flagged this as
provisional: "If a fifth mode emerges … revisit. Don't pre-add it"
(ADR-0001:40) — written in v1.0.0, before the Claude Code plugin
marketplace existed.

Three things have changed since:

1. **A second global channel now exists.** The plugin (`ai@yusufkaracaburun`)
   serves every ai-kit skill/agent/command at user scope with zero
   per-project setup. `docs/install-plugin.md:3` confirms this is
   Claude-Code-only — Cursor has no marketplace channel and stays fully
   dependent on the symlink-install or project-merge. ADR-0001's
   `install-global` axis modeled only the symlink-install; it has no
   concept of the plugin at all.
2. **`brownfield`'s real job turned out to be unrelated to skill-merge
   safety.** It changes six Tier-B defaults — lifecycle→`production`
   (`setup/SKILL.md:150`), Sandcastle skipped (`:378`), automation-recommender
   defaults `skipped` not `deferred` (`:380`, `:456`), architecture assumes
   existing conventions (`:406`, `:515`, `:529`, `:596`), and an extra
   `agent-stack.md` doc (`agent-stack-guide.md:24-26`). None of that is about
   whether `merge_skills` can safely coexist with a project's own custom
   skills — brownfield's linking values were always identical to
   `solo-both`'s (see above), so it never actually needed a distinct
   linking behavior in the first place.
3. **Skill-merge safety around custom entries is now universal, not
   brownfield-specific.** `link_preserving_custom`
   (`bin/lib/link-primitives.sh`, commit `7d25f8d`, shipped v1.78.3) makes
   `merge_skills`/`merge_agents`/`merge_commands` safe around a same-named
   custom entry under *every* mode — a real dir/file is always preserved,
   a symlink is preserved iff it resolves inside the project tree. Whatever
   residual argument existed for brownfield needing its own linking
   treatment is gone.

Live evidence the two-axis split is the right one: `ai-kit-upgrade.sh
--skip-skill-merge=true` (v1.79.0, same day as this ADR) exists purely
because a project on `project-only`/`brownfield` with the plugin already
installed had no way to say "don't merge anyway" — that flag is the
`project_skills_merged` boolean below, just wired in as a retrofit instead
of a first-class setup-time field.

Two real bugs surfaced doing this research, tracked separately (not fixed
by this ADR, both are inputs to Phase (a) below):

- `bin/ai-kit-doctor.sh:181` checks `~/.claude/plugins/marketplaces/ai-kit`
  — the pre-3.0-rename path (ADR-0004). The live path is
  `~/.claude/plugins/marketplaces/yusufkaracaburun/`. This check has
  likely never fired correctly since the rename.
- `bin/bootstrap-project.sh:16` / `bin/ai-kit-upgrade.sh:15`'s
  `case "$AIKIT" in */plugins/cache/*)` answers "is *this invocation's*
  `$AIKIT` a plugin-cache path," not "is the plugin installed on this
  machine." A dev clone invocation (this whole ai-kit repo, all session)
  resolves `$AIKIT` to the git clone even while the plugin is simultaneously
  installed and active — the two facts are independent.

## Decision

Replace the single `setup_mode` enum with three independent fields:

1. **`global_channel_available`** — auto-detected fact, no question asked.
   True iff the ai-kit plugin is installed at user scope (a *new*,
   standalone check — e.g. `[ -d "$HOME/.claude/plugins/cache/yusufkaracaburun/ai" ]`,
   not the stale doctor path and not a given script's own `$AIKIT`
   resolution) OR the legacy symlink-install has run
   (`~/.config/ai-kit/root` present). On Cursor this is always false for
   the plugin half — only the symlink-install can set it there.

2. **`project_skills_merged`** (boolean) — does this project *also* want
   ai-kit's skills merged into its own `.claude/skills` /
   `.agents/skills` / `.cursor/skills`, even when a global channel already
   serves it? One smart-defaulted question, not four label choices:
   default `false` when `global_channel_available=true` on Claude Code;
   default `true` when no global channel exists (nothing else would serve
   skills) or the host is Cursor. This is the exact primitive
   `--skip-skill-merge` and `bootstrap-project.sh`'s existing `SKILLS_MODE`
   (`merge-skills`/`link-all`/`no-skills`) already implement — this ADR
   promotes it from an upgrade-time retrofit to the first-class setup-time
   field, it does not invent a new mechanism.

3. **`brownfield`** (boolean, auto-detected via `detect-tooling.sh`,
   unchanged) — gates the six Tier-B defaults listed in Context, and
   *only* those. It never again feeds the linking decision.

The four legacy strings map onto this without information loss:

| Legacy mode | `global_channel_available` | `project_skills_merged` | `brownfield` |
| ----------- | --------------------------- | ------------------------ | ------------ |
| `solo-both` | true | true | false |
| `solo-global` | true | false | false |
| `project-only` | false (or declined) | true | false |
| `brownfield` | (whichever applies) | (whichever applies) | true |

## Consequences

**Positive**

- Removes a named concept instead of adding a fifth value to it — matches
  the user's own framing ("if ai-kit already exists global via the
  plugin, a symlink adds nothing") without inventing new vocabulary.
- `--skip-skill-merge` stops being a special-case escape hatch; it becomes
  the one real per-project question, asked once at setup time instead of
  discovered as a bug months later.
- `brownfield` no longer accidentally implies a skill-merge behavior it
  never actually had — its meaning shrinks to exactly what it does.

**Negative**

- Real blast radius: ~106 occurrences of `setup_mode`/the four literal
  strings across ~20 files (`ai-kit-doctor.sh` 23, `setup/SKILL.md` 17,
  `tests/bin/cases/lifecycle.sh` 14, `verify-setup.sh` 9,
  `agent-stack-guide.md` 8, `apply-marker.sh` 8, 13 more files at 1-6
  each). Every test fixture hardcoding one of the four strings needs
  review, not just a rename.
- Two independent doctor bugs (stale plugin path, invocation-scoped vs
  machine-scoped plugin detection) must be fixed as part of writing the
  new `global_channel_available` check, or the new field inherits broken
  detection on day one.
- `setup_mode`/`agent_stack` stay in `.ai-kit-setup` during the dual-write
  phase for backward compatibility with anything reading the old field
  directly; removing them is a separate, later decision.

**Follow-ups (phased — do not land in one shot)**

- (a) Fix `ai-kit-doctor.sh:181`'s stale marketplace path as its own
  isolated commit, independent of everything else here.
- (b) Write the new standalone `global_channel_available` check (does not
  yet change any behavior — read-only, tested against the 5 real
  `.ai-kit-setup` markers on disk).
- (c) Introduce `global_channel_available` / `project_skills_merged` as new
  marker fields, written *alongside* the existing `setup_mode` (dual-write,
  non-breaking) for at least one release.
- (d) Migrate `verify-setup.sh`, `ai-kit-doctor.sh`, and the setup-mode test
  fixtures to read the new fields; `setup_mode` becomes derived/display-only.
- (e) Only then: update `/ai:setup` Branch 0 to ask the one smart-defaulted
  question instead of the four-way choice, and deprecate the enum in
  a follow-up ADR once every consumer has migrated.
