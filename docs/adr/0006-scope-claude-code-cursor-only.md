# ADR-0006: Scope ai-kit to Claude Code and Cursor

## Status

Accepted (Unreleased)

## Context

ai-kit started as a Claude Code + Cursor toolkit and then grew multi-host
reach in two rounds:

1. **Rule emitters** (roadmap §1) — `bin/emit-rules.sh` gained per-host
   emitters for Aider, Cline, Continue, and Cody alongside Cursor and Claude
   Code, translating the canonical `standards/rules/*.mini.md` books into each
   host's conventional rule directory.
2. **MCP server** (roadmap §3, PR 3) — a Node + TypeScript stdio server
   (`mcp/`) exposing five read-only tools, published to npm as
   `@yusufkaracaburun/ai-kit-mcp`, to reach hosts with no native skill
   primitive: Cline, Continue, Zed, Claude Desktop.

The premise was "agent-agnostic distribution — reach every host." In practice
that premise did not hold for this project:

- ai-kit is developed and used exclusively on **Claude Code and Cursor**. No
  contributor or user here runs Aider, Cline, Continue, Cody, Zed, or Claude
  Desktop.
- The multi-host surface carried ongoing cost with no return: two extra CI
  workflows (`mcp.yml`, `mcp-publish.yml`), a published npm package with its
  own release path, a Node toolchain dependency, a TypeScript build, and
  ~30 files of documentation and tests describing hosts nobody exercises.
- Untested-in-practice paths are a maintenance liability: every refactor of
  `emit-rules.sh` or the install scripts had to reason about emitters and a
  server that were never run.

## Decision

Scope ai-kit to two hosts — **Claude Code and Cursor** — and delete the
multi-host surface.

### Removed

- **`mcp/`** — the entire MCP server (server, tools, resolve-root, tests,
  `package.json`) and its CI (`.github/workflows/mcp.yml`,
  `mcp-publish.yml`). The `@yusufkaracaburun/ai-kit-mcp` npm package is
  deprecated by the maintainer; ai-kit no longer publishes it.
- **`bin/lib/emitters/{aider,cline,cody,continue}.sh`** — the four
  non-CC/Cursor rule emitters, plus their `source` and dispatch wiring in
  `bin/emit-rules.sh` and their detection in `detect_agents()`.
- **`bin/ai-kit-mcp`** — the MCP wrapper script and its `~/.local/bin`
  symlink step in `install-global.sh`.
- All MCP/`mcp.json`-version wiring in `sync-plugin-version.sh` and
  `release.sh`; the corresponding tests in `tests/bin/run-tests.sh`.

### Kept

- **The `cursor` and `claude-code` emitters** — the two supported hosts.
- **The `generic` emitter** — it is *not* a host. It maintains the canonical
  `docs/agents/active-rules.md` rule index and is always emitted regardless
  of host. It stays.
- **User-project MCP detection** — `detect-tooling.sh` / `detect-lib.sh`
  still record `.mcp.json` / `.cursor/mcp.json` / `.vscode/mcp.json` in a
  project's agent stack, and `bootstrap-project.sh --with-mcp` still seeds a
  baseline `.cursor/mcp.json`. A Cursor (or Claude Code) project may run its
  own MCP servers — that is unrelated to ai-kit shipping one.

The historical "landed" entries in roadmap §1 and §3 are left intact as a
record of what was shipped and then deliberately removed.

## Consequences

**Positive**

- One fewer language toolchain (Node/TypeScript), one fewer published
  artifact, two fewer CI workflows. The repo is pure Bash + Markdown again.
- The five primitive types collapse to the ones both supported hosts can
  load: skill, subagent, slash command, hook, rule. (MCP tool was the sixth.)
- Every code path that ships now has a host that actually exercises it.

**Negative / trade-offs**

- ai-kit is no longer usable from Cline, Continue, Zed, or Claude Desktop.
  This is accepted: nobody using ai-kit runs those.
- The `@yusufkaracaburun/ai-kit-mcp@2.0.0` package remains on npm as a
  deprecated tombstone; npm does not allow true un-publishing after 72h.
- A future need to support another host means re-introducing an emitter (or
  an MCP server) rather than extending an existing multi-host abstraction.
  Judged unlikely enough to not pay for in advance.
