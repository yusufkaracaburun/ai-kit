---
id: defer-lead
skill: aikit-followup
expects:
  - detects environment (gh auth, remote, docs/roadmap.md presence) BEFORE mutating
  - drafts both the issue body and the roadmap paragraph and shows them to the user
  - asks for approval before running `gh issue create` or editing `docs/roadmap.md`
  - default label is `enhancement` unless the user passes `--label`
  - appends the roadmap entry to the LAST `## What's next` section, numbered after the existing entries
  - references the new issue in the roadmap paragraph as `(#N)` once the issue ID is known
  - if `gh` is unavailable, falls back to roadmap-only (local-only mode) and surfaces that
  - reports the issue URL and the roadmap line position at the end
  - does NOT close other issues, even if the new one supersedes them
---

# Prompt

We've been going back and forth on whether to extract the rule-scorer into
its own package — the current implementation lives in
`bin/lib/recommend-rules-lib.sh` and is starting to look like it deserves
to be a standalone tool that other ai-kit-like projects could vendor. It's
not blocking anything in this session, but I don't want to lose the
thread.

Defer this for later — open an issue + add it to the roadmap.