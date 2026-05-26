---
name: doc-to-skill
description: Convert a PDF / EPUB / DOCX / RTF / ODT / MD into a SKILL.md scaffold with chapter index, claim placeholders, sources list, and provenance credit. Use when the user wants to turn a book / spec / long-form doc into a project-scoped skill, or says "make a skill from this PDF", "convert this doc to a skill", "scaffold a skill from this paper".
---

# doc-to-skill

Turn one long-form document into a `SKILL.md` scaffold. **Scaffold only**
— the chapter index + claim placeholders give the agent a structured
hook to fill in real claims afterwards from the source. The skill does
not invent claims itself.

## When to invoke

- "Make a skill from this PDF / EPUB / DOCX."
- "Scaffold a skill from this paper / book / spec."
- "I have a long doc — convert it into a project skill."

If the user has a continuously-growing corpus of non-code documents
(meeting transcripts, research PDFs accumulating in one folder), point
them at `llm-wiki` instead — that is the wiki-shaped sibling. This skill
is the **one-shot deep-dive** axis.

## Input contract

A single document file readable by pandoc:

- PDF, EPUB, DOCX, RTF, ODT, Markdown.
- Path on disk (the skill does not download URLs).
- Pandoc must be on `PATH` — system install, not a repo dep.

## Process

### 1. Pick the slug + target

```bash
"$AI_KIT_ROOT/bin/doc-to-skill.sh" <source-file> [--name <slug>] [--target <dir>]
```

- `<slug>` defaults to the source basename slugified
  (`my-book.pdf` → `my-book`).
- `<dir>` defaults to `./skills` (or `workflow/skills` when run inside
  ai-kit-the-repo).

The script refuses to overwrite an existing `SKILL.md` at the target
path — re-runs require a different `--name` or removing the old
scaffold first.

### 2. Inspect the scaffold

The script writes `<target>/<slug>/SKILL.md` with:

- **Frontmatter** — `name` filled, `description` marked `TODO` (the
  user / agent rewrites it so the skill auto-selects on the right
  prompts).
- **Claims section** — three placeholder rows in the format
  `**Claim:** ... **Source:** \`<file>\`, § <chapter>.`. The agent
  replaces these with 5-15 concrete claims drawn from the source.
- **Chapter index** — H1 / H2 headings from the source (first 50),
  preserved as a nested markdown list. The navigation pointer for
  filling claims.
- **Sources** — the source path captured at scaffold time.
- **Provenance** — credit to `virgiliojr94/book-to-skill` (MIT) for the
  pattern, plus a generation timestamp.

### 3. Fill the claims

This is the deliberate handoff. The scaffold is structured enough that
the agent can walk the chapter index and produce real claims with
source citations. Recommended cadence:

- One claim per chapter / major section, max 15 total.
- Each claim is a single defensible sentence with a verbatim source
  reference (chapter heading is fine — page numbers when the source is
  paginated).
- After filling, rewrite the frontmatter `description` so the skill
  auto-selects on the prompts that match its claims.

### 4. Refine + commit

- Verify the skill triggers on the prompts you expect — Claude Code's
  skill-selection is keyword-driven from the `description` field.
- Commit the new directory under `workflow/skills/<slug>/` (ai-kit) or
  `skills/<slug>/` (consumer projects). Provenance line in the
  scaffold credits the upstream pattern; keep it on commit.

## Out of scope

- **Downloading URLs.** Pass a local file path; download separately.
- **OCR.** Image-only PDFs need OCR upstream (e.g.
  `ocrmypdf in.pdf out.pdf` then pass `out.pdf`).
- **`llm-wiki` integration.** Continuous wiki maintenance is a
  different shape; this skill ships exactly one scaffold per
  invocation.
- **Auto-claim extraction.** The script writes placeholders; the agent
  produces real claims by walking the chapter index against the
  source. Hard automation of claim extraction is a research arc — see
  catalog re-eval issue `#25` and the docling benchmark captured
  there.

## Trust model

- **Read-only on the source.** The script never edits the input
  document.
- **Refuses to overwrite an existing `SKILL.md`.** Re-scaffolding
  requires a different slug or removing the old file by hand.
- **Pandoc is a system dependency.** Not vendored; not added to
  repo-level deps. If pandoc is missing, the script exits with a clear
  pointer to the install page.

## Provenance

Pattern adapted from
[virgiliojr94/book-to-skill](https://github.com/virgiliojr94/book-to-skill)
(MIT). ai-kit ports only the structural scaffold; PKM-vault bits
(wiki / summaries writes, commit hooks, eod / integrations) are
intentionally dropped. The provenance line is also stamped into every
generated scaffold so consumer skills carry the credit forward.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot
patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" doc-to-skill start
bash "$AI_KIT_ROOT/bin/log-skill.sh" doc-to-skill done   # or `abort` if you bail
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
