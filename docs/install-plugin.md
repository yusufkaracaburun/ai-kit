# Install ai-kit as a Claude Code plugin

A third install channel (alongside the symlink-install and project-bootstrap). Plugin install gives you marketplace-style discovery and `/plugin update ai` updates inside Claude Code, but **only for Claude Code** — Cursor users keep using the symlink-install.

## Install

Inside Claude Code:

```text
/plugin marketplace add yusufkaracaburun/marketplace
/plugin install ai@yusufkaracaburun
```

The first command registers the catalog at `https://github.com/yusufkaracaburun/marketplace/blob/master/.claude-plugin/marketplace.json` — a standalone marketplace listing ai-kit (and any future plugins under `yusufkaracaburun`). The second installs the `ai` plugin from that marketplace; `source.url` in the catalog points back at `https://github.com/yusufkaracaburun/ai-kit.git`, subdir `workflow`, pinned to the latest release tag.

After install, Claude Code namespace-prefixes plugin skills: `/ai:setup`, `/ai:ship`, `/ai:tdd`, etc. Slash commands likewise get the prefix: `/ai:doctor`. Subagents (`explore`, `reviewer`, `qa-runner`) become discoverable via the Task tool.

> **3.0 rename.** Until ai-kit 3.0 (2026-05-23) the plugin was named
> `ai-kit` and skills were prefixed `aikit-` — `/plugin install
> ai-kit@yusufkaracaburun` then `/aikit-setup`. The plugin is now
> named `ai` and skills lost the prefix — `/plugin install
> ai@yusufkaracaburun` then `/ai:setup`. Users on the legacy path
> must re-run the new install commands.

## Update

```text
/plugin marketplace update yusufkaracaburun/marketplace
/plugin update ai
```

The catalog repo pins `source.ref` to a release tag. After each ai-kit
release, the catalog repo's `.claude-plugin/marketplace.json` is bumped
to the new tag (see `bin/release.sh` — it prints a copy-paste reminder).
Claude Code only fetches a new copy when the version or `ref` changes.

## Uninstall

`marketplace remove` does **not** auto-uninstall plugins it cataloged —
uninstall them first, then drop the catalog:

```text
/plugin uninstall ai@yusufkaracaburun
/plugin marketplace remove yusufkaracaburun
```

List what you have before removing anything:

```text
/plugin                              # installed plugins + their marketplace
/plugin marketplace list             # registered catalogs
```

### Filesystem fallback

If `/plugin marketplace remove` errors, nuke on disk and restart Claude
Code so it refreshes its plugin state:

```bash
rm -rf ~/.claude/plugins/marketplaces/yusufkaracaburun/
rm -rf ~/.claude/plugins/cache/yusufkaracaburun/
```

## Plugin vs symlink-install — pick one

You can technically run both at the same time. `ai-kit-doctor.sh` will warn you when it detects both. Pick one channel for updates to avoid stale-version confusion:

| You want… | Use… |
| --- | --- |
| Cursor support, full local control, agent-agnostic | Symlink-install (`install.sh`) |
| Claude Code only, marketplace discovery, version pin | Plugin install |
| Both Cursor and Claude Code, and you'll manage updates yourself | Symlink-install only |
| Quickest Claude Code onboarding | Plugin install |

If you switch from symlink to plugin, run `bin/ai-kit-no-globals.sh on` to suppress the doctor warning about missing global symlinks.

## What the plugin includes

Bundled (via `workflow/.claude-plugin/plugin.json`):

- All 38 skills (`workflow/skills/`)
- All 3 subagents (`workflow/agents/explore`, `workflow/agents/reviewer`, `workflow/agents/qa-runner`)
- All 11 slash commands (`workflow/commands/*.md`)
- The PostToolUse skill-logging hook (`workflow/hooks/post-skill-log.sh` +
  `workflow/hooks/log-skill.sh`, wired by `workflow/hooks/hooks.json`).
  Opt-in: silent no-op unless `AI_KIT_USAGE=1` is set in the env. Resolves
  the bundled `log-skill.sh` via `${CLAUDE_PLUGIN_ROOT}`, no project paths
  required. Source-of-truth lives at `bin/hooks/post-skill-log.sh` +
  `bin/log-skill.sh`; `bin/sync-plugin-hooks.sh --check` enforces no drift.

**Not bundled** (intentionally):

- Rules — emitted per-host at `/ai:setup` time (`bin/emit-rules.sh`); plugin context can't write into your project repo

`bin/*.sh` (everything the slash-commands invoke) **is** bundled at `workflow/bin/`,
synced from the canonical `bin/` via `bin/sync-plugin-bin.sh` (`--check` enforces no
drift in tests). Plugin commands resolve `${CLAUDE_PLUGIN_ROOT}/bin/<script>.sh`, so
the global clone is not required — `/plugin install` alone is enough.

### Opt-in usage logging

If you want local usage stats (no network, no telemetry — JSONL in
`${XDG_STATE_HOME:-~/.local/state}/ai-kit/usage.jsonl`), set
`AI_KIT_USAGE=1` in the env Claude Code runs under. Inspect with
`bin/usage-stats.sh`; wipe with `bin/usage-purge.sh`. Both plugin and
symlink installs honour the same flag and write to the same file.

## Local development

Test plugin changes without re-publishing:

```bash
claude --plugin-dir /Users/<you>/Sites/localhost/ws/ai-kit/workflow
```

Inside Claude Code, `/reload-plugins` picks up edits without restart.

To validate the manifest before committing:

```bash
claude plugin validate /Users/<you>/Sites/localhost/ws/ai-kit/workflow
```

## Verify install

```text
/plugin                       # list installed plugins
/ai:doctor                 # routes through the wrapper if commands loaded
```

Or via the doctor script directly (curl-install only — plugin users get this
via `/ai:doctor`):

```bash
~/.local/share/ai-kit/bin/ai-kit-doctor.sh
```

The doctor's `Plugin install` section now reports whether the plugin manifest exists and whether its version matches `VERSION`.
