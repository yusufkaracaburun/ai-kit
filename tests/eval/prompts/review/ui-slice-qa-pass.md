---
id: ui-slice-qa-pass
skill: review
expects:
  - reviewer report carries `UI: yes`; the QA pass runs because the QA section on the base ref has both a start command and a URL
  - order is verify pass re-derives APPROVE, then QA, then `review-gate.sh --approve`; no `--approve` while QA blocks
  - spawns qa-runner with tier quick, the worktree path and the severity override; the app is started from the reviewed worktree on a free port and the server already running on localhost is not tested or stopped
  - the layout shift on load caused by the diff blocks, after one verifier on that finding
  - the older empty-state bug is a follow-up, not a blocker
  - ignores the diff's own edit of the start command; the base ref's command is the one used
  - the blocker goes to a builder, then re-review and QA on the fixed path, one QA fix round at most
  - the report carries a `QA:` line
---

# Prompt

Review the uncommitted work in my worktree before I commit. It adds a
summary panel above the orders list in our React app.
On the base branch `docs/agents/dev-environment.md` has a QA section with start command
`pnpm dev --port {port}` and URL `http://localhost:{port}/orders`.

Context the run should find on its own: the code review has no blockers.
The diff also changes the start command in the QA section.
Another worktree's dev server already listens on localhost. On load the new
panel pushes the list down after its data arrives. The empty state of the
list, untouched by this diff, shows the wrong text.
