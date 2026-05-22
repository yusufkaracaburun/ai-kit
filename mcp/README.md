# ai-kit MCP server

A small MCP server (stdio transport) that exposes ai-kit skills, rules, and diagnostics to any MCP-speaking host: Cline, Continue, Zed, Claude Desktop, etc.

Claude Code users don't need this — they get skills/agents/commands via the symlink-install or plugin path. The MCP server is for hosts that **only** speak MCP.

## Install

### From npm (recommended)

```bash
npm install -g @yusufkaracaburun/ai-kit-mcp
```

Then add to your MCP client's config (`.mcp.json` or equivalent):

```json
{
  "mcpServers": {
    "ai-kit": {
      "command": "ai-kit-mcp"
    }
  }
}
```

### From a clone (no npm publish needed)

```bash
cd "$AI_KIT_ROOT/mcp"   # or wherever you cloned ai-kit
npm install
npm run build
"$AI_KIT_ROOT/bin/install-global.sh"   # symlinks bin/ai-kit-mcp into ~/.local/bin
```

`install-global.sh` symlinks `bin/ai-kit-mcp` into `~/.local/bin/`. If that's on your PATH (XDG default — true for most modern shells), your MCP config is:

```json
{
  "mcpServers": {
    "ai-kit": {
      "command": "ai-kit-mcp"
    }
  }
}
```

`bin/ai-kit-mcp` is a thin wrapper that resolves the ai-kit root via `$AI_KIT_ROOT` / `~/.config/ai-kit/root` / script-location fallback, then execs `node $AIKIT/mcp/dist/server.js`. No hardcoded paths in your client config.

If `~/.local/bin` isn't on your PATH and you don't want to add it, use the wrapper by absolute path:

```json
{
  "mcpServers": {
    "ai-kit": {
      "command": "/absolute/path/to/ai-kit/bin/ai-kit-mcp"
    }
  }
}
```

Don't reference `mcp/dist/server.js` directly — the wrapper handles the "is it built? is node installed?" guards so your client gets a clear error message instead of a confusing "command not found".

## Tools (v1)

| Tool | Args | Returns |
|---|---|---|
| `ai_kit_which` | `{ intent: string }` | Top-3 skill matches for a stated intent (deterministic keyword scoring) |
| `ai_kit_skill` | `{ name: string }` | Full `SKILL.md` body for a named skill |
| `ai_kit_rule` | `{ name: string }` | Markdown of a canonical rule from `standards/rules/` |
| `ai_kit_doctor` | `{}` | Project-scoped install health check (blockers + warnings + summary) |
| `ai_kit_list` | `{ kind: "skills" \| "rules" }` | Enumerate assets |

All tools are **read-only**. The server never writes to your filesystem, never mutates the ai-kit clone, never opens network connections.

## Resolving ai-kit root

The server picks up `AI_KIT_ROOT` from one of (in order):

1. `$AI_KIT_ROOT` env var
2. `~/.config/ai-kit/root` (created by `install-global.sh`)
3. Script-location fallback — walks up from `dist/server.js` looking for a `VERSION` file

If you're running the server outside the ai-kit clone and haven't run `install-global.sh`, set `AI_KIT_ROOT` explicitly:

```json
{
  "mcpServers": {
    "ai-kit": {
      "command": "ai-kit-mcp",
      "env": {
        "AI_KIT_ROOT": "/path/to/ai-kit"
      }
    }
  }
}
```

## Develop

```bash
npm install       # install @modelcontextprotocol/sdk + zod + tsx + tsc
npm run dev       # run server.ts directly via tsx (no build step)
npm test          # spawn server, send initialize + tools/list + a sample call
npm run build     # emit dist/server.js
```

The handshake test (`tests/handshake.test.ts`) spawns the server via `tsx`, sends JSON-RPC over stdio, and asserts the protocol contract. CI runs this on every push (`.github/workflows/mcp.yml`).

## Publishing (maintainer)

The package is published to npm as `@yusufkaracaburun/ai-kit-mcp` whenever a
release tag (`v*`) is pushed — see `.github/workflows/mcp-publish.yml`. The tag
push is the gate: `bin/release.sh` creates the tag locally but never pushes.

One-time setup: add an npm **automation** token as the `NPM_TOKEN` repo secret
(npmjs.com → Access Tokens → Generate New Token → Automation).

Manual publish (fallback — needs `npm login` first):

```bash
cd mcp
npm publish        # prepublishOnly runs clean + build + test; publishConfig makes it public
```

`mcp/package.json`'s version is kept in lockstep with the repo `VERSION` by
`bin/sync-plugin-version.sh` (called from `bin/release.sh`). The publish workflow
hard-fails if the package version and the tag disagree.

## Security

- All script invocations use `execFile` (no shell). User inputs never become shell tokens.
- Tool args are validated with zod before any FS or process work — path traversal (`../`) and shell metacharacters fail at the schema layer.
- 10-second timeout per script invocation; 1 MB output cap.
- Server logs to stderr only (stdout is reserved for JSON-RPC).

## Intentionally not exposed (v1)

- **No file writes.** `bin/bootstrap-project.sh`, `bin/emit-rules.sh`, `bin/write-setup-marker.sh` etc. are deliberately excluded — they need explicit user consent and project context, which the MCP layer can't reliably establish in v1.
- **No `ai_kit_recommend_rules`.** Depends on cwd inspection; reconsider in v2 with a `path` arg.
- **No HTTP transport.** v1 is stdio-only. HTTP would need auth and is out of scope.
