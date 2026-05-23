---
name: setup-gh-workflow
description: Install ai-kit's GitHub workflow hygiene — issue templates with DoR/DoD checklists, two workflows (close→DoD check, label→DoR check, auto-promote Todo→Ready), and P0-P3 + epic/* + area/* + status:in-progress labels. Tier-A — fires from `/ai:setup` when a GitHub remote is detected. Dutch default; `--lang en` for English. Use when user wants to set up GH issues + Projects with enforced DoR/DoD, or invokes `/ai:setup-gh-workflow`.
---

# Setup GitHub workflow

Install `.github/ISSUE_TEMPLATE/` (feature + spike templates with embedded DoR/DoD), two `.github/workflows/` files (DoR/DoD enforcement + auto-promote-to-Ready), and a bulk label set into the current project. Adopt-as-pattern from naschool (`/should-i-use` verdict 2026-05-23) — battle-tested, parsing logic verbatim.

## When to invoke

Trigger phrases:

- "set up GH issues + Projects"
- "wire DoR/DoD enforcement"
- "scaffold GitHub workflow"
- "install the issue templates"
- `/ai:setup-gh-workflow [--lang en]`

Also fires automatically as part of `/ai:setup` when the project has a GitHub remote — silent skip on non-GH remotes; never asks for opt-in.

**Not this skill** — use [`to-issues`](../to-issues/SKILL.md) when you want to *break down a plan* into N tickets. `setup-gh-workflow` scaffolds the templates + workflows themselves; `to-issues` populates them later. Use [`to-prd`](../to-prd/SKILL.md) in defer mode when you want to park a single lead — that opens one issue + roadmap entry; this skill is the one-time platform setup.

## What it installs

| Artifact | Purpose |
| -------- | ------- |
| `.github/ISSUE_TEMPLATE/feature.md` | Standard feature/bugfix template — Triage / Scope / Acceptance / DoR / DoD |
| `.github/ISSUE_TEMPLATE/spike.md` | Time-boxed research template — adds Time-box + ADR-output DoD |
| `.github/ISSUE_TEMPLATE/config.yml` | Disables blank issues; links to project board |
| `.github/workflows/dor-dod-enforcement.yml` | On close → check DoD, reopen if unchecked. On `labeled status:in-progress` → check DoR, strip label if unchecked. |
| `.github/workflows/auto-promote-ready.yml` | Todo → Ready on board when DoR all checked + `P[0-3]-*` + `epic/*` + `area/*` labels set. Forward-only. |
| Labels (via `gh label create --force`) | `P0-critical`, `P1-high`, `P2-medium`, `P3-low`, `epic/core`, `epic/ux`, `area/backend`, `area/frontend`, `area/infra`, `area/docs`, `status:in-progress` |

## Process

### 1. Run the bootstrap script

```bash
bin/setup-gh-workflow.sh /path/to/project              # Dutch templates (default)
bin/setup-gh-workflow.sh /path/to/project --lang en    # English templates
bin/setup-gh-workflow.sh /path/to/project --dry-run    # preview only
```

The script:

1. **Detects** the GitHub remote (`git remote get-url origin`). Silent exit if not `github.com`.
2. **Copies** templates + workflows from `context/templates/github/`. **Never overwrites** existing files — pass `--force` to opt in.
3. **Bulk-creates labels** via `gh label create --force` (idempotent — updates color/description on re-run).
4. **Detects** existing GitHub Project for the repo owner; if found, resolves the Status field ID + Todo/Ready option IDs via `gh api graphql` and substitutes them into `auto-promote-ready.yml`. If no project board, prints the manual setup steps.

### 2. Manual follow-ups the script prints

Two things the script intentionally does not do silently (config anti-pattern):

- **Project board creation** — the script never auto-creates a Project. If none exists, it prints:
  ```bash
  gh project create --owner <owner> --title "<repo> board"
  ```
  After creating it, add a Status field with options Todo / Ready / In Progress / Done, then re-run `setup-gh-workflow.sh` to substitute the resolved IDs.

- **`PROJECT_TOKEN` secret** — `auto-promote-ready.yml` needs a PAT (Personal Access Token classic with `project` + `repo` scope, OR fine-grained PAT with Projects:read+write + Issues:read + user-projects scope). `GITHUB_TOKEN` cannot touch Projects v2. The script prints:
  ```bash
  gh secret set PROJECT_TOKEN --repo <owner>/<repo>
  ```

### 3. Customize labels per project

`epic/core` and `epic/ux` ship as placeholders. Rename them per project — every issue needs an `epic/*` label for the DoR enforcement + auto-promote to trigger.

`area/*` defaults cover backend / frontend / infra / docs. Adjust to your project's modules (e.g. naschool uses `area/portal` / `area/partner` / `area/admin` / `area/backend`).

## After install

Every new issue must carry:

- One `P[0-3]-*` label (priority).
- One `epic/*` label (epic membership).
- One or more `area/*` labels (where in the codebase).

To start work, add `status:in-progress`. The DoR workflow strips the label if any DoR checkbox is unchecked. To close, every DoD checkbox must be ticked or the close workflow reopens the issue.

Issues already on the project board with all DoR checkboxes + the three required label categories filled auto-promote Todo → Ready.

## Boundaries

- **Existing files never overwritten** — `--force` is opt-in. Bootstrap is safe on a repo that already has its own templates.
- **Silent skip on non-GitHub remotes** — GitLab / Bitbucket / no-remote projects get nothing.
- **No auto-project-create** — projects v2 needs a PAT secret; auto-create + auto-secret hides what the workflow needs. Detect-only, print manual steps.
- **Dutch templates default** — naschool source language. English variant via `--lang en` flag.

## Flags

| Flag | Behaviour |
| ---- | --------- |
| `--lang nl` (default) | Dutch issue templates |
| `--lang en` | English issue templates |
| `--force` | Overwrite existing template + workflow files |
| `--dry-run` | Print actions, change nothing |
| `--no-labels` | Skip label creation (manual creation later) |
| `--no-project` | Skip project-board detection + placeholder substitution |
| `--quiet` | Only print errors |

## Outputs

- `.github/ISSUE_TEMPLATE/{feature,spike,config}.{md,yml}` in the project
- `.github/workflows/{dor-dod-enforcement,auto-promote-ready}.yml` in the project
- Labels in the GitHub repo (idempotent)
- Substituted Project IDs in `auto-promote-ready.yml` + project board URL in `config.yml` if a project board exists
- Console reminders for PAT secret + manual project-board creation if needed
