---
id: fresh-github-repo
skill: setup-gh-workflow
expects:
  - detects the GitHub remote via git remote get-url origin before doing anything
  - silent-skips when the remote is not github.com (no .github/ scaffolded)
  - copies feature.md + spike.md + config.yml into .github/ISSUE_TEMPLATE/
  - copies dor-dod-enforcement.yml + auto-promote-ready.yml into .github/workflows/
  - never overwrites existing template files without --force
  - bulk-creates labels P0-P3 / epic/* / area/* / status:in-progress via gh label create --force
  - detects existing project board for owner; resolves Status field + Todo/Ready option IDs via gh api graphql
  - substitutes AI_KIT_PROJECT_* placeholders into auto-promote-ready.yml when project found
  - prints PROJECT_TOKEN secret setup reminder + manual gh project create command when no board exists
  - defaults to Dutch templates; --lang en swaps to English variants
---

# Prompt

Set up GitHub workflow hygiene on this repository. It's a fresh repo
with a GitHub remote (`yusufkaracaburun/myproject`), no `.github/`
folder yet, no project board. I want the Dutch templates.

# Expected behaviour

The skill should:

1. Detect the GitHub remote.
2. Copy issue templates (feature + spike + config) into
   `.github/ISSUE_TEMPLATE/`.
3. Copy workflows (DoR/DoD enforcement + auto-promote-to-Ready) into
   `.github/workflows/`.
4. Bulk-create the required labels.
5. Print a reminder to create a project board + add the
   `PROJECT_TOKEN` repo secret before the auto-promote workflow
   becomes functional.

The skill should NOT:

- Auto-create the project board (config anti-pattern).
- Overwrite any pre-existing template files without `--force`.
- Run anything network-wise beyond the `gh` calls (no curl, no
  external fetches).
