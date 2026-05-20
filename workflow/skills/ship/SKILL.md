---
name: ship
description: Deploy a release to production or staging — pre-flight checks, release notes, deploy via project CI or docs, post-deploy smoke test. Use when landing an increment or closing a sprint increment.
---

# Ship

Release a working increment. Stack-agnostic — derive deploy commands from `docs/agents/dev-environment.md`, CI config, or official docs.

## Process

1. **Pre-flight**
   - Run or confirm `review` passed (no open blockers)
   - CI green on the release branch (`gh run list`, GitHub Actions, GitLab CI, etc.)
   - All related issues linked to the PR/release

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

Inspired by [gstack /ship](https://github.com/garrytan/gstack) — stripped of gstack-specific tooling.
