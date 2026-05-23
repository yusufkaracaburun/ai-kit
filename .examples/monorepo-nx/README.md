# Monorepo (Nx)

An Nx workspace with `apps/` and `libs/`, npm package manager, Playwright e2e tests, existing `.cursor/rules/playwright/*.mdc` and `.cursor/mcp.json` + `.vscode/mcp.json`. Inspired by the dogfood-portal case.

## Starting tree (relevant slice)

```
workspace/
├── apps/
│   ├── web/
│   └── admin/
├── libs/
│   ├── ui/
│   ├── data/
│   └── feature-search/
├── nx.json
├── package.json
├── package-lock.json
├── .cursor/
│   ├── mcp.json
│   ├── rules/
│   │   └── (none yet at top level)
│   └── playwright/
│       └── .cursor/rules/        # nested rules dir (Cursor supports this)
│           ├── playwright.mdc
│           ├── locators.mdc
│           └── ... (11 mdc files)
└── .vscode/
    └── mcp.json
```

Nested `.cursor/rules/` under `playwright/` is a real Cursor pattern — ai-kit detects it.

## Detection snapshot

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
```

Highlights:

```json
{
  "package_manager": { "name": "npm", "install": "npm install" },
  "frameworks": ["nx"],
  "agent_stack": {
    "recommendation": "brownfield",
    "needs_agent_stack_doc": true,
    "cursor": {
      "rules_custom": [
        ".cursor/playwright/.cursor/rules/playwright.mdc",
        ".cursor/playwright/.cursor/rules/locators.mdc"
      ]
    },
    "mcp": [".cursor/mcp.json", ".vscode/mcp.json"]
  },
  "architecture": { "monorepo": true, "frontend": "nx-monorepo" }
}
```

Two MCP configs detected (Cursor + VS Code) and 11 nested custom rules → strongly brownfield.

## Setup commands — Tier A

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
$AI_KIT_ROOT/bin/detect-tooling.sh . --write-agent-stack
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .
$AI_KIT_ROOT/bin/detect-tooling.sh . --write
$AI_KIT_ROOT/bin/write-setup-marker.sh . \
  --setup-mode=brownfield --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped \
  --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

## After Tier A — what changed

- `.agents/skills/` created with 16 ai-kit skill symlinks.
- `.cursor/skills/` populated alongside the (none-yet) custom skills bucket.
- `.cursor/rules/` was **not touched** — including the nested `playwright/.cursor/rules/*`.
- `.cursor/mcp.json` and `.vscode/mcp.json` are untouched.
- `docs/agents/agent-stack.md` documents the 11 playwright rules and 2 MCP configs that coexist.
- `docs/agents/dev-environment.md` lists Nx + npm docs URLs.

## When to add Tier B branches

This monorepo benefits from Tier B in three places:

1. **Architecture branch** (`docs/agents/architecture.md`) — record the apps/libs convention and the import boundaries Nx enforces.
2. **Domain branch** — for a project that has explicit bounded contexts under `libs/`, the domain glossary doc is worth it.
3. **Workflow branch** — if the team uses Scrum/Kanban with GitHub Projects, capture it.

Re-run `/ai:setup` and pick "Full" — `.ai-kit-setup` ensures you only get prompted for branches you haven't decided yet.

## Two MCP gotchas

- ai-kit recognises `.mcp.json` (Claude Code), `.cursor/mcp.json` (Cursor), and `.vscode/mcp.json` (VS Code) as the same kind of config. Detection lists all three; bootstrap modifies none.
- If you opt-in to the baseline template via `bootstrap-project.sh --with-mcp`, it will **skip** when any of the three already exist — it never overwrites.
