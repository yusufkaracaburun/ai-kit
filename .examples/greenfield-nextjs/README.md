# Greenfield Next.js

A fresh `create-next-app` repo, TypeScript, App Router, no AI tooling yet. The happy path — `solo-both` mode, Tier A, ~5 minutes end-to-end.

## Starting tree

```
my-next-app/
├── app/
│   └── page.tsx
├── public/
├── package.json
├── pnpm-lock.yaml
├── next.config.mjs
├── tsconfig.json
└── .gitignore
```

No `.cursor/`, no `.agents/`, no `AGENTS.md`, no `CLAUDE.md`. Empty agent state.

## Detection snapshot

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh . --json
```

Relevant fields:

```json
{
  "package_manager": { "name": "pnpm", "install": "pnpm install" },
  "frameworks": ["nextjs", "react"],
  "agent_stack": {
    "recommendation": "solo-both",
    "needs_agent_stack_doc": false,
    "cursor": { "skills_aikit": [], "skills_custom": [], "rules_custom": [] },
    "agents":  { "skills_aikit": [], "skills_custom": [] },
    "mcp": []
  }
}
```

ai-kit recommends `solo-both` because there's no existing agent state to preserve.

## Setup commands

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"

# 1. Bootstrap (merge-skills = symlink each ai-kit skill, preserves any custom ones)
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .

# 2. Dev environment doc — writes docs/agents/dev-environment.md with detected URLs
$AI_KIT_ROOT/bin/detect-tooling.sh . --write

# 3. Mark setup done at Tier A
$AI_KIT_ROOT/bin/write-setup-marker.sh . \
  --setup-mode=solo-both \
  --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped \
  --architecture=skipped --sandcastle=false

# 4. Verify
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

Total elapsed: <5 minutes on the first try (most time is choosing the setup mode in the agent UI).

## Ending tree

```
my-next-app/
├── .agents/
│   └── skills/        # symlinks to $AI_KIT_ROOT/workflow/skills/*
│       ├── diagnose -> .../ai-kit/workflow/skills/diagnose
│       ├── ship     -> .../ai-kit/workflow/skills/ship
│       ├── tdd      -> .../ai-kit/workflow/skills/tdd
│       └── ... (16 total)
├── .cursor/
│   └── skills/        # parallel symlinks
├── docs/
│   ├── adr/
│   │   └── ADR-template.md
│   ├── agents/
│   │   └── dev-environment.md      # detected: Next.js + pnpm docs URLs
│   └── wiki/
│       └── README.md
├── AGENTS.md          # generic, tool-agnostic
├── CLAUDE.md          # Claude Code wrapper
├── CONTEXT.md         # empty domain glossary, ready to fill
├── .ai-kit-setup      # setup-mode=solo-both, tier=minimal
└── (original files)
```

## What's not configured (Tier B leftovers)

`/ai:setup` Full path would add:

- `docs/agents/docker.md` (none / existing / minimal)
- `docs/agents/issue-tracker-*.md`
- `docs/agents/workflow.md` (Scrum / Kanban)
- `docs/agents/architecture.md` (optional FE/BE layout doc)
- `.sandcastle/` for parallel agent runs

For a solo greenfield project, Tier A is usually enough until the team grows.

## What to do next

1. Fill `CONTEXT.md` with your domain glossary (use `grill-with-docs` skill).
2. Write the first PRD with `to-prd` — even rough; it gets refined.
3. Open an issue list with `to-issues`.
4. Pick the first ticket and run `tdd` on it.
