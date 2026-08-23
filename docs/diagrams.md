# Diagrams

Two views of the same kit. The first shows how primitives *reach* a host; the
second shows what happens *during* a turn. For the prose version see
[architecture.md](architecture.md) (wiring) and [mental-model.md](mental-model.md)
(skill choreography).

## Wiring — how a primitive reaches the host

```mermaid
flowchart LR
  subgraph SRC["Source layer — ai-kit repo (single source of truth)"]
    S["workflow/skills/*/SKILL.md<br/>39 skills"]
    A["workflow/agents/*/AGENT.md<br/>3 subagents"]
    C["workflow/commands/*.md<br/>11 slash commands"]
    R["standards/rules/*.mini.md<br/>35 agent-agnostic rules"]
    H["bin/hooks/*.sh + hooks.json<br/>2 hook wirings"]
    B["bin/ai-kit-*.sh<br/>doctor · next · status · hygiene …"]
    T["context/templates/<br/>AGENTS.md · CONTEXT.md"]
  end

  subgraph DIST["Distribution layer"]
    IG["install-global.sh<br/>symlink, machine-wide"]
    BP["bootstrap-project.sh<br/>symlink, per-project"]
    PL["workflow/.claude-plugin/plugin.json<br/>+ marketplace repo"]
    ER["bin/emit-rules.sh<br/>EMITTER: rules to host format"]
    EA["bin/emit-agents.sh<br/>EMITTER: SKILL.md sections into AGENT.md"]
  end

  subgraph CC["Host: Claude Code"]
    CCS["~/.claude/skills/ · proj/.claude/skills/"]
    CCA["~/.claude/agents/"]
    CCC["~/.claude/commands/ → /ai:doctor …"]
    CCH["proj/.claude/settings.json<br/>PreToolUse + PostToolUse"]
    CCR["rules as skill-text"]
  end

  subgraph CU["Host: Cursor"]
    CUS["~/.cursor/skills/ · proj/.cursor/skills/"]
    CUR["proj/.cursor/rules/*.mdc"]
    CUN["no subagents<br/>skill falls back to inline checklist"]
  end

  subgraph HA["Host-agnostic"]
    AG["~/.agents/skills/"]
    PRJ["proj/AGENTS.md · proj/CONTEXT.md<br/>proj/.ai-kit-setup marker"]
  end

  S --> IG & BP & PL
  A --> IG & PL
  A -. "shared content, CI checks drift" .- EA
  S -. EA
  C --> IG & PL
  R --> ER
  H --> PL & BP
  T --> BP

  IG --> CCS & CCA & CCC & CUS & AG
  BP --> CCS & CCH & CUS & PRJ
  PL --> CCS & CCA & CCC & CCH
  ER --> CUR & CCR
  A -.-> CUN
  B --- C
```

Two rules carry the whole tree: **symlinks, not copies** — a `git pull` in the
source layer updates every host at once — and **emitters** for anything that
cannot be symlinked, either because each host wants a different format (rules)
or because the artifact shares content with another one (agent ← skill).

One exception the diagram flattens: `workflow/bin/` is a *copy* of `bin/`, not a
symlink, because the plugin must be self-contained under `${CLAUDE_PLUGIN_ROOT}`.
`bin/sync-plugin-bin.sh` keeps the two in step and CI fails on drift. Editing a
script under `bin/` therefore means re-running that sync.

## Runtime — what happens in one turn

```mermaid
flowchart TD
  U["User prompt or /ai:command"]

  U --> SEL{"Host matches<br/>skill description"}
  U --> CMD["/ai:doctor · /ai:next · /ai:status<br/>slash command"]

  SEL -->|match| SK["Skill runs<br/>e.g. tdd · review · qa · diagnose"]
  CMD --> BIN["Bash → bin/ai-kit-*.sh<br/>deterministic, no LLM"]
  BIN --> OUT

  SK --> CTX["Reads CONTEXT.md · docs/adr/ · rules"]
  CTX --> SK

  SK --> TOOL["Tools: Read · Grep · Bash · Edit · Write"]
  SK --> DEL{"Claude Code?"}

  DEL -->|yes| SUB["Subagent in its own context<br/>reviewer · qa-runner · explore"]
  DEL -->|no, Cursor| INL["Inline checklist inside the skill<br/>same source, no Task tool"]

  SUB --> REP["Structured report back<br/>≤300 lines, raw output stays isolated"]
  REP --> SK
  INL --> SK

  TOOL --> HK1
  SK --> HK2

  subgraph HOOKS["Hooks — deterministic, outside the model's control"]
    HK1["PreToolUse matcher=Bash|Grep|Glob<br/>repo-wide sweep → delegate to a sub-agent<br/>(or query the graph, when graphify-out/ exists)"]
    HK2["PostToolUse matcher=Skill<br/>usage log, only when AI_KIT_USAGE=1"]
  end

  HK1 --> SK
  SK --> OUT["Proposal to the user<br/>ai-kit never commits on its own"]
```

## One line per primitive

- **Skill** — a workflow with a `description:` the model routes to on its own.
  The only primitive the LLM picks autonomously.
- **Subagent** — the same workflow in its own context window, so browser and
  grep output never reaches your main context. Claude Code only; Cursor gets the
  inline variant emitted from the same source.
- **Slash command** — a thin wrapper around a bash script. No LLM decision, so
  the output is reproducible.
- **Hook** — the only layer guaranteed to run regardless of what the model
  decides. That is why the search-delegation nudge lives here and not in a rule:
  `context-discipline` already *says* "delegate wide exploration", but a rule is
  prose the model skips under pressure. The hook fires anyway — and only on a
  repo-wide sweep, so a scoped `Grep` stays silent and the nudge stays signal.
- **Rule** — cross-cutting guidance with no trigger, emitted to host format at
  `/ai:setup` time.
- **Tool** — what a skill has in hand (Read/Bash/Edit). Provided by the host,
  not defined by ai-kit.

Rule of thumb from [architecture.md](architecture.md): if the answer is "two of
these at once", one is primary and the other should defer to it.
