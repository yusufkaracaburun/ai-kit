---
id: staging-smoke
skill: qa
expects:
  - identifies critical paths (auth, primary CRUD, payment if present) before testing
  - prefers Playwright or browser MCP when available; falls back to curl + manual checks
  - reports each bug with concrete repro steps and expected vs actual
  - does NOT silently fix without surfacing the bug first
  - confirms the build/deploy version under test (not just the URL)
---

# Prompt

We just deployed to staging at https://staging.example.com. Run a smoke
test of the critical paths before we promote to production tomorrow morning.
Report bugs with repro steps.
