---
id: check-docs
skill: docs-sync
expects:
  - runs `bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-docs-sync.sh"` against the project
  - summarises the dead-links section by file:line + missing path
  - reports total findings count + per-section exit code
  - surfaces the driver's summary line verbatim (clean / findings reported)
  - never proposes auto-edits — only manual fix suggestions per finding
  - skips external URLs, anchor-only links, image links, HTML <a href>, bare URLs, and links inside code fences (does not flag them as broken)
  - mentions that /ai:hygiene covers install health while /ai:docs-sync covers content drift (so the user knows they are complementary, not duplicate)
---

# Prompt

I'm about to open a PR and want to make sure the docs in this repo still line up. Some files got renamed last sprint and I'm worried we have dead markdown links pointing at the old paths. Can you check the docs and tell me what to fix?
