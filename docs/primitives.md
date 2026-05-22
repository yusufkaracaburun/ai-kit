# Which primitive should I use?

You want to extend ai-kit. Which primitive type fits? This page is a decision tree, not a feature catalogue — for definitions see [glossary.md](glossary.md); for how it all fits together see [architecture.md](architecture.md).

The rule: pick the **most constrained** primitive that does the job. A skill is more constrained than a hook; a slash command is more constrained than a skill. Constrained = fewer ways to go wrong.

---

## Decision tree

```
Start: "I want to add X to ai-kit"
│
├─ Does X automate something that should fire on a host event
│  (before/after a tool, on session start, on user prompt)?
│  │
│  └─ YES → HOOK
│           Source: bin/hooks/<name>.sh
│           Registered in: .claude/settings.json
│           Example: post-skill-log.sh fires on PostToolUse(Skill)
│
├─ Is X a short prompt template the user will invoke explicitly
│  with `/<name>` (possibly with arguments)?
│  │
│  ├─ Does it just wrap one of bin/ai-kit-*.sh for IDE-native UX?
│  │  │
│  │  └─ YES → SLASH COMMAND
│  │           Source: workflow/commands/<name>.md
│  │           Example: /aikit-doctor wraps bin/ai-kit-doctor.sh
│  │
│  └─ Does it have a multi-step workflow with instructions?
│     │
│     └─ NO → SLASH COMMAND
│        YES → continue (probably a skill)
│
├─ Is X a multi-step workflow that should be discovered when the
│  user describes their intent (no explicit `/` invocation)?
│  │
│  ├─ Does it need an isolated context to do heavy reading/analysis
│  │  without polluting the main conversation?
│  │  │
│  │  ├─ YES (and Claude Code is acceptable as primary host)
│  │  │   → SUBAGENT called from a SKILL
│  │  │     Source: workflow/agents/<name>/AGENT.md
│  │  │     Example: review skill delegates to aikit-reviewer
│  │  │
│  │  └─ NO → SKILL
│  │         Source: workflow/skills/<name>/SKILL.md
│  │         Example: ship, tdd, retro
│  │
│  └─ (continued from above) just a workflow → SKILL
│
├─ Is X cross-cutting guidance that should apply in *every* skill,
│  in every host, without auto-loading?
│  │
│  └─ YES → RULE
│           Source: standards/rules/<name>.mini.md
│           Emitter: extend bin/emit-rules.sh if needed
│           Example: git-hygiene, context-discipline
│
├─ Is X a user-facing diagnostic / utility script (no LLM in the loop)?
│  │
│  └─ YES → BIN SCRIPT
│           Source: bin/ai-kit-<name>.sh
│           Optional: wrap as slash command for IDE UX
│           Example: ai-kit-doctor.sh, ai-kit-which.sh
│
└─ Is X a per-project file template (mostly literal, light variable
   expansion at bootstrap time)?
   │
   └─ YES → TEMPLATE
            Source: context/templates/<name>.template
            Consumer: bin/bootstrap-project.sh
            Example: AGENTS.md.template, CONTEXT.md.template
```

---

## Worked examples

### "Add auto-formatting on every file save"
- Fires on a tool event (after Write/Edit) → **HOOK** (PostToolUse matcher `^(Write|Edit)$`)
- Wraps a project's `prettier` / `black` / `gofmt` invocation
- Source: `bin/hooks/post-format.sh`
- Wired in: `.claude/settings.json`

### "Nudge me when I edit code the docs describe"
- Fires on a tool event (after Edit/Write/MultiEdit) → **HOOK** (PostToolUse matcher `Edit|Write|MultiEdit`)
- Deterministic shell — greps `CONTEXT.md` / `docs/adr/` for the edited path, no LLM
- Source: `bin/hooks/context-drift-check.sh`; installed by `bin/apply-context-drift-hook.sh` (ADR-0005)

### "Show me which skill fits my current task"
- User wants explicit `/` invocation → **SLASH COMMAND**
- Wraps an existing script (`bin/ai-kit-which.sh`) → fits the wrapper case
- Source: `workflow/commands/aikit-which.md`

### "Run a heavy security audit on changed files before merge"
- Multi-step workflow → skill territory
- Heavy reading of files would pollute main context → delegate to a **SUBAGENT**
- Source: `workflow/skills/aikit-review/SKILL.md` calls `workflow/agents/aikit-reviewer/AGENT.md`

### "Always remind the LLM to write Conventional Commits"
- Cross-cutting, applies everywhere → **RULE**
- Source: `standards/rules/git-hygiene.mini.md` (already exists)
- Emitted via `bin/emit-rules.sh` at `/aikit-setup`

### "Generate a fresh PRD from a one-paragraph idea"
- Multi-step LLM workflow, auto-discovered by intent → **SKILL**
- Source: `workflow/skills/aikit-to-prd/SKILL.md` (already exists)
- No isolated context needed; runs in main thread

---

## Anti-patterns

- **Skill that just runs one shell command** — should be a slash command (or bin script). Skills are for multi-step LLM workflows, not aliases.
- **Hook that calls the LLM** — hooks are deterministic shell. If you need LLM logic on an event, the hook should *invoke a skill via slash command* or just leave it as a skill the user runs explicitly.
- **Rule that's project-specific** — rules are cross-cutting. Project-specific guidance belongs in `CONTEXT.md` or `docs/adr/`.
- **Subagent for a one-shot task in main context** — if you don't actually need isolation, just do it inline. Subagents add a hop; don't pay for it gratuitously.
- **Slash command duplicating a skill** — pick one. If the workflow is multi-step and discovery-by-description matters, it's a skill. If it's "run this script and summarize," it's a slash command.

---

## Two questions to ask yourself

1. **Constraint test.** "Could this be a more constrained primitive type?" If yes, prefer that one. A hook beats a skill beats a subagent in determinism.
2. **Host-reach test.** "Will this need to work in Cursor?" If yes, avoid Claude Code-only primitives (subagent, plugin features). Use skills + rules + bin scripts.

If you're still uncertain, write a short paragraph describing X and grep `workflow/skills/`, `bin/`, `standards/rules/` for the closest existing analog. Mirror its shape.
