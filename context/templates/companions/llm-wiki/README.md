# llm-wiki glue

Scaffold for a **self-maintaining knowledge base** — the LLM Wiki pattern.
`aikit-recommend-tools` copies this skeleton into a project when the user wants to
ingest **non-code documents** (specs, transcripts, research, PDFs) into an
interlinked wiki the agent keeps current.

Pattern from Andrej Karpathy's `llm-wiki.md` idea document, popularised by
Balu Kosuri's [`balukosuri/llm-wiki-karpathy`](https://github.com/balukosuri/llm-wiki-karpathy).
ai-kit ships **its own** schema adapting the pattern — it does not vendor either
upstream repo. Same precedent as the concepts ai-kit adopted from `gstack` and
`mattpocock/skills` (see the README provenance table).

| Template file | Becomes, in the project |
| ------------- | ----------------------- |
| `wiki-schema.md` | `wiki/SCHEMA.md` — the agent's operating manual |
| `wiki/index.md` | `wiki/index.md` — master catalog of every page |
| `wiki/overview.md` | `wiki/overview.md` — big-picture synthesis |
| `wiki/glossary.md` | `wiki/glossary.md` — terms + naming conventions |
| `wiki/log.md` | `wiki/log.md` — timestamped operation history |

The skill also creates an empty `raw/` (source documents — agent-read-only) and
appends a pointer block to `AGENTS.md`.

## Viewers

The `wiki/` layout (markdown + `[[wiki-link]]` + YAML frontmatter) is
Obsidian-compatible out of the box — no plugins or config needed. Any markdown
reader works; Obsidian is the most polished option because it adds:

- **Graph view** — visualise cross-references between pages
- **Obsidian Copilot** (community plugin) — LLM chat against the vault from
  mobile / tablet, useful for query and synthesis when away from the desk
- **Web Clipper** (browser extension) — save articles directly into `raw/`

ai-kit does not depend on Obsidian and does not ship any Obsidian-specific
templates, plugins, or sync configuration — the layout just happens to be
compatible.

## Relationship to graphify

**For code knowledge, use graphify instead** — it indexes the codebase via AST.
llm-wiki is for knowledge that is *not* code; recommending both for the same
need is redundant.
