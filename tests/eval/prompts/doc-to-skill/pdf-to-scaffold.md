---
id: pdf-to-scaffold
skill: doc-to-skill
expects:
  - reads the source document (PDF / EPUB / DOCX / etc.) before producing output
  - produces a SKILL.md scaffold, not a finished skill — chapter index + claim placeholders, no invented claims
  - frontmatter has name, description, and a trigger phrase derived from the document's topic
  - chapter index mirrors the source document's heading structure
  - sources list cites the original document with title + author when available
  - provenance credit to virgiliojr94/book-to-skill (MIT) is present
  - refuses to overwrite an existing SKILL.md at the target path without explicit confirmation
  - defaults output path to workflow/skills/ inside ai-kit, ./skills/ in consumer repos
---

# Prompt

I downloaded "A Philosophy of Software Design" (Ousterhout) as
`docs/sources/aposd.pdf`. Turn it into a project-scoped skill so I can
reference its principles from `/ai:review` and `/ai:improve-codebase-
architecture`. Don't write the claims yet — just the scaffold with the
chapter index and placeholders for me to fill in from the source.
