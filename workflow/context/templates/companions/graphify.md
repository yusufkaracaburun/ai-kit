## graphify (knowledge graph)

This project uses [graphify](https://github.com/) — a knowledge graph of the
codebase at `graphify-out/`. It returns a scoped subgraph per query, usually far
smaller than raw grep output or the full `GRAPH_REPORT.md`.

The AST-derived wiki at `graphify-out/wiki/` is the **graphify-wiki** — not to
be confused with the curated **llm-wiki** at `wiki/` if both companions are
scaffolded. See the disambig block below or `wiki/SCHEMA.md` for the split.

Rules:

- For codebase questions, run `graphify query "<question>"` first when
  `graphify-out/graph.json` exists — scoped subgraph beats grepping raw files.
- Use `graphify path "<A>" "<B>"` for the relationship between two things, and
  `graphify explain "<concept>"` for a focused concept.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation instead of
  browsing raw source.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review, when
  `query` / `path` / `explain` do not surface enough.
- After modifying code, run `graphify update .` to keep the graph current
  (AST-only, no API cost).
- Tune `.graphifyignore` at the project root to exclude generated /
  vendored paths (e.g. `node_modules/`, `vendor/`, build outputs) before
  the first `graphify .` run, so the graph indexes source — not junk.
