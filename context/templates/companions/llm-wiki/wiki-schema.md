# Wiki schema

Operating manual for this project's self-maintaining knowledge base. Pattern
adapted from Andrej Karpathy's `llm-wiki.md`. The agent reads this file before
any wiki operation.

## Layout

- `raw/` — source documents. **Read-only for the agent** — never edit, move, or
  delete anything here. Originals stay exactly as the user dropped them.
- `wiki/` — agent-owned. The agent creates and maintains every file here. The
  user browses it; the user does not hand-write wiki pages.
- `wiki/sources/` — one summary page per `raw/` document.

## Page types

| Type | Path | Holds |
| ---- | ---- | ----- |
| source | `wiki/sources/<slug>.md` | summary of one raw document + link to it |
| concept | `wiki/<slug>.md` | one idea, term, or system — cross-referenced |
| entity | `wiki/<slug>.md` | a product, feature, persona, or component |
| analysis | `wiki/<slug>.md` | a saved answer to a useful query |
| index | `wiki/index.md` | master catalog of every page |
| overview | `wiki/overview.md` | big-picture synthesis — evolves over time |
| glossary | `wiki/glossary.md` | terms, definitions, naming conventions |
| log | `wiki/log.md` | timestamped record of every operation |

Link pages with `[[wiki-link]]` syntax. Only link where understanding page A
genuinely changes how you see page B — tight linking beats dense linking, three
meaningful cross-references outperform fifteen weak ones. Every new page must
still be linked from at least one existing page and listed in `index.md` — no
orphans.

## Operations

### Ingest

Trigger: the user drops a file in `raw/` and says "ingest `<path>`".

1. Read the document fully.
2. Surface key takeaways to the user; ask what to emphasise.
3. Write `wiki/sources/<slug>.md` — a summary plus a link to the raw file.
4. For each product / feature / persona / concept found: create its page, or
   update the existing one.
5. Add new terms to `glossary.md`.
6. Add every new page to `index.md`.
7. Update `overview.md` if the big picture shifted.
8. Flag contradictions with existing pages — never silently overwrite.
9. Append a timestamped entry to `log.md`.

One source = one ingest pass. Do not batch-ingest silently — the user guides
each one.

### Query

Trigger: the user asks a question.

- Read `index.md` first, then drill into the relevant pages. Answer from the
  **wiki**, not from `raw/`.
- Cite the pages used.
- Offer to save a genuinely useful answer as an `analysis` page so the
  exploration compounds instead of vanishing into chat history.

### Lint

Trigger: the user says "lint the wiki".

Report — do not auto-fix — and ask which fixes to apply:

- contradictions between pages
- stale claims newer sources have replaced
- orphan pages with no inbound links
- missing cross-references
- concepts mentioned but lacking their own page
- inconsistent terminology

## Session start

At the start of a wiki session, read `index.md` + `overview.md` to load the
current state of the knowledge base.
