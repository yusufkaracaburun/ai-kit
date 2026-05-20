# Dogfood: portal monorepo

Validated detection against [portal](file:///Users/ykaracabur001/ws/portal) (Nx monorepo).

## v1.0 recommended choices

| Step | Detection | Choice |
| ---- | --------- | ------ |
| Tier | — | **A (fast)** unless team needs full docs |
| Setup mode | MCP + Playwright rules | **brownfield** |
| Bootstrap | greenfield ai-kit files | `--merge-skills` + `install-global` |
| Dev env | npm + nx | `--write`, verify nx.dev |
| Tier B | optional later | docker, tracker, domain, architecture, workflow |

## Detection snapshot

```
Setup mode: brownfield (needs agent-stack doc: true)
Custom rules: .cursor/playwright/.cursor/rules/*.mdc (11)
MCP: .cursor/mcp.json, .vscode/mcp.json
Architecture: nx-monorepo + libs/
```

## Tier A commands

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
$AI_KIT_ROOT/bin/detect-tooling.sh . --write-agent-stack
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .
$AI_KIT_ROOT/bin/detect-tooling.sh . --write
# refine dev-environment.md URLs
$AI_KIT_ROOT/bin/write-setup-marker.sh . --setup-mode=brownfield --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

Extend to Tier B later with `/setup` Full path.
