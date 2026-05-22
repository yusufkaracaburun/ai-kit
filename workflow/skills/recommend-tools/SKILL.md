---
name: recommend-tools
description: Recommend and wire optional companion tools (graphify, caveman, llm-wiki) into the current project — external tools and patterns ai-kit configures but does not vendor. Use when the user asks "should I add graphify, caveman, or a self-maintaining wiki", "set up companion tools", "optimize my AI setup further", "fewer tokens", or after /setup to layer extra capability.
---

Recommend and wire **companion tools** for this project — external AI-productivity tools that sit alongside ai-kit's lifecycle skills. ai-kit configures them; it never vendors or auto-installs them. Same trust model as `recommend-rules`: surface, let the user choose, wire only what they pick.

## What a companion tool is

A third-party tool *or pattern* that improves the AI coding setup but is **not** part of ai-kit's agile lifecycle. ai-kit owns the *integration glue* (a rules block, a hook, a scaffold), never the tool itself. Three are known today:

| Companion | Optimizes | Effect | Risk |
| --------- | --------- | ------ | ---- |
| **graphify** | Input — what the AI reads about the code | Knowledge graph; scoped subgraph per query instead of raw grep. Large token cut on multi-file repos. | Low — invisible infra, just better retrieval. |
| **caveman** | Output — how verbosely the AI replies | Compresses responses (drops articles/filler/hedging), technical content intact. ~65% fewer output tokens. | Medium — it is a *communication mode*, opinionated. |
| **llm-wiki** | Memory — knowledge from non-code documents | Self-maintaining wiki; ingests specs/transcripts/research into interlinked pages. The wiki, not the raw files, is the artifact that compounds. | Low — additive scaffold; the agent owns `wiki/`, never touches `raw/`. |

They are orthogonal to each other and to ai-kit. Recommend per project, never blanket.

## When to invoke

- After `/setup`, when the user wants to push the setup further than rules + skills.
- When the user asks "should I add graphify / caveman here", "make this cheaper", "fewer tokens".
- On a brownfield repo with many files — graphify earns its keep fastest there.

## Process

### Phase 1 — Detect

Check what is already present on the machine and in the repo:

```bash
command -v graphify >/dev/null 2>&1 && echo "graphify: CLI present" || echo "graphify: not installed"
[ -d graphify-out ] && echo "graphify: already initialised in this repo" || echo "graphify: not initialised here"
{ [ -d "$HOME/.claude/skills/caveman" ] || [ -d .claude/skills/caveman ]; } && echo "caveman: skills present" || echo "caveman: not installed"
{ [ -d wiki ] && [ -d raw ]; } && echo "llm-wiki: scaffolded in this repo" || echo "llm-wiki: not scaffolded here"
```

Report the three lines plainly. Detection drives the recommendation — never claim a tool is wired when it is not.

### Phase 2 — Recommend per project

Judge fit against the actual repo, do not blanket-recommend:

- **graphify** — strong fit when the repo has many files / is brownfield / the user greps a lot. Weak fit for a tiny single-file repo. If the CLI is missing, point the user at the upstream install (one line); a focused web search for the current install command is fine — do not guess it.
- **caveman** — a cost saver, low risk to *install*, but it changes how the agent talks. **Always opt-in, never a default.** Recommend only if the user explicitly wants compressed output. Nobody should be surprised by caveman prose.
- **llm-wiki** — strong fit when the project accumulates **non-code documents** (PRDs, meeting transcripts, competitor research, PDFs) the user re-reads to find things. Weak fit for a pure code repo — **graphify** already indexes code. Do not recommend graphify and llm-wiki for the *same* need; they cover code vs. documents respectively.

State, for each: present-or-not, fit for *this* repo, and the one-line why.

### Phase 3 — Wire what the user picks

Glue templates live in `$AI_KIT_ROOT/context/templates/companions/`. Wire only the tools the user agreed to.

**graphify:**
1. Append `companions/graphify.md` to the project `AGENTS.md` (agent-agnostic — both Claude Code and Cursor read it). Skip if an equivalent block is already there.
2. Claude Code only: merge the `PreToolUse` hook from `companions/graphify-hook.json` into the project `.claude/settings.json`. It nudges the agent toward `graphify query` over raw grep once `graphify-out/graph.json` exists. Merge into the existing `hooks` object — do not clobber other hooks.
3. Tell the user to run `graphify .` (or the upstream's init command) once to build `graphify-out/`, then `graphify update .` after code changes.

**caveman:**
1. Append `companions/caveman.md` to the project `AGENTS.md` — a short note that the mode exists and how to toggle it. caveman ships its own skills via its own installer; ai-kit only documents it.
2. Do not enable it. The note states it is opt-in.

**llm-wiki:**
1. Skip if `wiki/` already exists. Otherwise scaffold from `companions/llm-wiki/`: copy `wiki-schema.md` → project `wiki/SCHEMA.md`, copy the starter pages (`index.md`, `overview.md`, `glossary.md`, `log.md`) → project `wiki/`, and create an empty `raw/` for source documents.
2. Append a short pointer block to `AGENTS.md`: where the wiki lives, that `wiki/SCHEMA.md` is the operating manual, and the three operations — ingest / query / lint.
3. Tell the user to drop a document in `raw/` and say "ingest" to start. Obsidian is an optional viewer for the wiki — mention it, do not install it.

### Phase 4 — Output contract

End by reporting:

- **Wired:** which tools, which files changed (`AGENTS.md`, `.claude/settings.json`).
- **Needs install:** any recommended tool whose CLI/skills are missing — with the upstream pointer.
- **Deferred:** tools the user said "later" to.
- **Next step:** for graphify, the init command to run.

If a file edit or merge failed, say so. Never report a tool wired when its glue is not on disk.

## Trust model

- **Never vendor.** ai-kit does not copy graphify or caveman source into the repo. They install from their own upstreams; ai-kit writes only the glue. For llm-wiki, ai-kit ships its own schema adapting a public pattern (Karpathy's `llm-wiki.md`) — it vendors no upstream repo.
- **llm-wiki: `raw/` is the user's, `wiki/` is the agent's.** The agent never edits or deletes anything under `raw/`.
- **Never auto-install** the tool itself — surface the install pointer, the user runs it.
- **caveman is never a default.** Opt-in only; the agent must not start compressing output unprompted.
- The graphify hook is additive context only — it cannot block a tool call, only suggest.
