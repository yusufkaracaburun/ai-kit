---
id: document-heavy-wiki
skill: aikit-recommend-tools
expects:
  - detects whether a wiki/ + raw/ scaffold already exists before recommending llm-wiki
  - recommends llm-wiki for a project heavy in non-code documents, with a one-line why
  - does NOT recommend graphify for the same need — graphify indexes code, llm-wiki indexes documents
  - scaffolds from context/templates/companions/llm-wiki/ — copies wiki-schema.md to wiki/SCHEMA.md, the starter pages to wiki/, creates an empty raw/
  - ai-kit ships its own schema adapting Karpathy's llm-wiki.md pattern — never vendors an upstream repo
  - appends a pointer block to AGENTS.md; mentions Obsidian as an optional viewer but does not install it
  - states that the agent owns wiki/ and never edits raw/
  - ends with an explicit wired / needs-install / deferred breakdown
---

# Prompt

This repo is mostly a product workspace — PRDs, customer-interview transcripts,
competitor PDFs, sprint retros. Hardly any code. I keep losing track of which
document said what. Is there a companion tool that would help, and how would you
set it up?
