## inspo-mcp (real production-site references)

[inspo-mcp](https://github.com/Nutlope/inspo) is an MCP server over a curated
archive of 832 production sites / 2,320 screens — real exemplars, not a style
taxonomy.

- Use it when a design read names a vibe ("Linear-style", "Awwwards-experimental",
  "premium consumer") that needs a concrete site to anchor against, not a guess
  from training-data associations. `find_examples_for_macrostructure`,
  `find_similar`, `find_by_color`, and `compare` pull real comparables on demand.
- `get_design_system` / `find_reference_jsx` turn a chosen exemplar into concrete
  tokens and copy-pasteable component code.
- Complements `ui-ux-pro-max` (style/palette taxonomy, no real screenshots) and
  `skillui` (tokens from one URL the user already names) — this is the "pull a
  comparable real site" step neither covers.
- Free, no API key. Vendor-hosted only (no self-host path) — availability and
  pricing depend on the maintainer keeping it free; search text and hex colors
  go to inspo's backend, no project code.
- Not installed silently: on yes, `npx -y inspo-mcp install` (auto-detects
  Claude Code/Cursor/VS Code/Windsurf/Zed/Claude Desktop and writes its own
  MCP config).
