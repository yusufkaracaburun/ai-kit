---
name: ship
description: Deploy a release to production or staging — pre-flight checks, release notes, deploy via project CI or docs, post-deploy smoke test. Use when landing an increment or closing a sprint increment.
---

# Ship

Release a working increment. Stack-agnostic — derive deploy commands from `docs/agents/dev-environment.md`, CI config, or official docs.

## Process

1. **Pre-flight**
   - Review must pass before merge — this is a precondition, not a
     recommendation. Run or confirm `/ai:review` passed with no open
     blockers and no security findings ≥ high. Human review of the diff
     is required even when the project has only one human contributor
     (see ai-kit issue #52 for the 2-dev-default rationale).
   - CI green on the release branch (`gh run list`, GitHub Actions, GitLab CI, etc.)
   - All related issues linked to the PR/release
   - Commit messages + PR title follow [git-hygiene rule](../../../standards/rules/git-hygiene.mini.md) (conventional commits, scoped, imperative); PR body uses the project's `.github/pull_request_template.md` if present

2. **Release notes**
   - Summarise changes from commits or PR description
   - List breaking changes and migration steps if any

3. **Deploy**
   - Use the project's deploy path: CI pipeline, `Makefile`, README, or official hosting docs
   - Do not assume a specific platform — read `docs/agents/dev-environment.md` first
   - If deploy is manual, give exact commands and wait for user confirmation before running destructive steps

4. **Post-deploy**
   - Run `qa` quick tier against staging/production URL if applicable
   - Verify critical paths manually if no E2E exists

5. **Done**
   - Close release issues
   - Tag or changelog entry if the project uses semver/tags
   - Note deploy time and version in the issue or release
   - Run the cross-cue helper and surface its output verbatim if it prints anything:
     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-docs-sync-nudge.sh" "<project_path>" --context=ship
     ```
     It conditionally suggests `/ai:hygiene` (install + framework wiring health) and/or `/ai:docs-sync` (universal content drift — dead links, repo-hygiene, finished-work cleanup). The finished-work check in `/ai:docs-sync` is especially relevant right after a release: it spots merged branches still hanging around locally and GitHub issues whose closing PR is in the release. Silent when nothing applies.

## Output

```markdown
## Pre-flight
- [ ] Review: PASS
- [ ] CI: green

## Release notes
...

## Deploy
Command / pipeline: ...

## Post-deploy
- Smoke: PASS | FAIL — details

## Verdict
SHIPPED | BLOCKED — reason
```

Inspired by [gstack /ai:ship](https://github.com/garrytan/gstack) — stripped of gstack-specific tooling.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" ship start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" ship done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

