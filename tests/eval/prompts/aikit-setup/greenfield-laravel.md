---
id: greenfield-laravel
skill: aikit-setup
expects:
  - runs detect-tooling --json (or equivalent) before asking branch questions
  - asks ONE setup-mode question with a recommendation (solo-both / project-only / brownfield / solo-global)
  - defaults to Tier A (fast path); only enters Tier B if the user explicitly asks
  - runs verify-setup --strict (or --strict --minimal) before claiming done
  - does NOT claim success if verify-setup exits non-zero
---

# Prompt

Set up ai-kit on this repository. It's a fresh Laravel 11 + Vue 3 admin
panel, no existing skills or rules, no Docker. I want the fast path.
