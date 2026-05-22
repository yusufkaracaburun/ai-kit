# Brownfield Laravel + Inertia

An existing Laravel 11 app with Inertia + Vue, already wired up for Cursor — has `.cursor/rules/*.mdc`, a `.cursor/mcp.json`, and a `.cursor/skills/my-team-skill/`. The team doesn't want their tooling clobbered.

## Starting tree (relevant slice)

```
project/
├── app/
├── resources/js/Pages/
├── routes/
├── composer.json
├── composer.lock
├── package.json
├── pnpm-lock.yaml
├── .cursor/
│   ├── mcp.json
│   ├── rules/
│   │   ├── inertia.mdc
│   │   ├── laravel.mdc
│   │   └── tailwind.mdc
│   └── skills/
│       └── my-team-skill/
│           └── SKILL.md
└── (no .agents/, no AGENTS.md, no CLAUDE.md)
```

## Detection snapshot

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh . --json | jq '{package_manager, frameworks, agent_stack}'
```

```json
{
  "package_manager": { "name": "composer", "install": "composer install" },
  "frameworks": ["laravel", "inertia"],
  "agent_stack": {
    "recommendation": "brownfield",
    "needs_agent_stack_doc": true,
    "cursor": {
      "skills_custom": ["my-team-skill"],
      "rules_custom":  [".cursor/rules/inertia.mdc", ".cursor/rules/laravel.mdc", ".cursor/rules/tailwind.mdc"]
    },
    "mcp": [".cursor/mcp.json"]
  },
  "architecture": { "frontend": "laravel-inertia", "backend": "laravel-default" }
}
```

Three signals push the recommendation to **brownfield**: custom skills, custom rules, and MCP config. `needs_agent_stack_doc: true` means ai-kit will generate a `docs/agents/agent-stack.md` documenting the coexistence.

## Setup commands — Tier A

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"

# 1. Document the existing agent stack BEFORE bootstrap, so nothing is silent
$AI_KIT_ROOT/bin/detect-tooling.sh . --write-agent-stack
#   → wrote docs/agents/agent-stack.md

# 2. Bootstrap with merge-skills (preserves my-team-skill/)
$AI_KIT_ROOT/bin/bootstrap-project.sh --minimal --merge-skills .

# 3. Dev environment with Laravel-version-aware docs URLs (reads composer.lock)
$AI_KIT_ROOT/bin/detect-tooling.sh . --write

# 4. Mark + verify
$AI_KIT_ROOT/bin/write-setup-marker.sh . \
  --setup-mode=brownfield \
  --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped \
  --architecture=skipped --sandcastle=false
$AI_KIT_ROOT/bin/verify-setup.sh . --strict --minimal
```

## After Tier A

```
project/
├── .agents/skills/                # new
│   ├── diagnose -> .../ai-kit/workflow/skills/aikit-diagnose
│   ├── ship     -> ...
│   └── ... (16 total)
├── .cursor/
│   ├── mcp.json                   # untouched
│   ├── rules/
│   │   ├── inertia.mdc            # preserved
│   │   ├── laravel.mdc            # preserved
│   │   └── tailwind.mdc           # preserved
│   └── skills/
│       ├── my-team-skill/         # preserved (custom)
│       ├── diagnose  -> .../ai-kit/workflow/skills/aikit-diagnose
│       └── ... (16 ai-kit skills symlinked alongside)
├── docs/
│   ├── adr/ADR-template.md
│   ├── agents/
│   │   ├── agent-stack.md         # documents the brownfield coexistence
│   │   └── dev-environment.md     # Laravel 11.x + Composer + Vite docs
│   └── wiki/README.md
├── AGENTS.md                       # added
├── CLAUDE.md                       # added
├── CONTEXT.md                      # added (empty, to fill)
└── .ai-kit-setup
```

The team's existing rules and MCP config are **untouched**. The custom `my-team-skill` is still discoverable. ai-kit adds alongside, not on top.

## Optional Tier B — add architecture branch

The codebase has `app/Domain/` and `app/Application/` style folders. To capture that:

```bash
# Re-run /aikit-setup in the agent, accept "Full" path this time, only enable branch 7
# Or run the branch manually:
mkdir -p docs/agents
cp $AI_KIT_ROOT/context/templates/docs/agents/architecture.md docs/agents/architecture.md
# Fill it in — paths under app/, the layering rules, what FE/BE share
```

## What changed in the team's day-to-day

- Cursor still picks up `inertia.mdc`, `laravel.mdc`, etc. — nothing regressed.
- `/aikit-diagnose`, `/aikit-ship`, `/aikit-tdd`, `/aikit-retro` now work from ai-kit.
- `my-team-skill` is still invokable.
- New devs read `AGENTS.md` first, then `docs/agents/agent-stack.md` for the coexistence map.

## What did NOT happen

- ai-kit did **not** modify `.cursor/mcp.json`.
- ai-kit did **not** overwrite or delete `inertia.mdc`, `laravel.mdc`, or `tailwind.mdc`.
- ai-kit did **not** symlink `.cursor/skills` to itself (would have wiped `my-team-skill`); `--merge-skills` is the default for this reason.
