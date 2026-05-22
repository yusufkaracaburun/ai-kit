# Install ai-kit as a Claude Code plugin

A third install channel (alongside the symlink-install and project-bootstrap). Plugin install gives you marketplace-style discovery and `/plugin update ai-kit` updates inside Claude Code, but **only for Claude Code** — Cursor users keep using the symlink-install.

## Install

Inside Claude Code:

```text
/plugin marketplace add yusufkaracaburun/ai-kit
/plugin install ai-kit@ai-kit
```

The first command registers the marketplace catalog at `https://github.com/yusufkaracaburun/ai-kit/blob/master/.claude-plugin/marketplace.json`. The second installs the `ai-kit` plugin from that marketplace.

After install, Claude Code namespace-prefixes plugin skills: `/ai-kit:setup`, `/ai-kit:ship`, `/ai-kit:tdd`, etc. Slash commands likewise get the prefix: `/ai-kit:aikit-doctor`. Subagents (`aikit-explore`, `aikit-reviewer`) become discoverable via the Task tool.

## Update

```text
/plugin marketplace update yusufkaracaburun/ai-kit
/plugin update ai-kit
```

Or skip the marketplace step and rely on the version field: `VERSION` is mirrored into `.claude-plugin/marketplace.json` and `workflow/.claude-plugin/plugin.json` by `bin/sync-plugin-version.sh` on every release. Claude Code only fetches a new copy when the version field changes.

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

- All 20 skills (`workflow/skills/`)
- Both subagents (`workflow/agents/aikit-explore`, `workflow/agents/aikit-reviewer`)
- All 5 slash commands (`workflow/commands/aikit-*.md`)

**Not bundled** (intentionally):

- Rules — emitted per-host at `/aikit-setup` time (`bin/emit-rules.sh`); plugin context can't write into your project repo
- The PostToolUse skill-logging hook — install via the symlink path if you want it (`AI_KIT_USAGE=1` opt-in)
- The `bin/` shell scripts — not exposed by the plugin; if you want `/aikit-doctor` to work you need `AI_KIT_ROOT` set in env (the slash command resolves it)

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
/aikit-doctor                 # routes through the wrapper if commands loaded
```

Or via the doctor script directly:

```bash
~/.local/share/ai-kit/bin/ai-kit-doctor.sh
```

The doctor's `Plugin install` section now reports whether the plugin manifest exists and whether its version matches `VERSION`.
