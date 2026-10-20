## OpenSEO (SEO, rank tracking, AI visibility)

- [OpenSEO](https://github.com/every-app/open-seo) gives the agent an MCP server
  and skills for SEO research, rank tracking and AI visibility (GEO/AEO).
- Hosted: the official [Claude Code plugin](https://openseo.so/docs/claude-code-plugin).
  Self-host: add your instance's [MCP URL](https://openseo.so/docs/mcp) and the
  public skills, not the plugin. The plugin's `.mcp.json` points at
  app.openseo.so, so installing it too registers a second openseo MCP.
- OpenSEO ships a skill named `seo-audit`. If this project has its own
  `seo-audit` skill, check which one loads.
- Research tools spend credits (hosted) or your DataForSEO budget (self-host).
