# Ship brief

One change gets one ship brief. A single general-purpose subagent (Task tool) runs commit, PR, merge and deploy, in that order, and stops at the first red check or at a deploy the user has not approved. The lead writes the brief and reads the report; it never runs these steps itself. One spawn for the whole chain, because a spawn per step mostly pays start-up cost.

Skills that hand off to it: `to-prd` (Defer mode), `autonomous`, `harvest`, `diagnose`.

## Rules for the subagent

- Precondition: the staged tree carries a `/ai:review` APPROVE; stage nothing beyond the reviewed paths.
- Run the steps in order; skip a step only when its field says `none`.
- Stage by path and read `git diff --staged` before the commit. Never `git commit -a`, `--no-verify` or a force push.
- A failed hook, a denied commit or push, or a red CI check is a stop: report the command and its output, change nothing else.
- Merge only when the field says so and the project's merge policy allows it. Deploy only when the user approved this deploy in this conversation; otherwise stop before it and print the deploy command (see the `deployment-on-demand` rule).
- After a squash merge, delete the local branch only once `gh pr view <n> --json state` says `MERGED`: switch to the base, then `git branch -D <branch>`. `-d` refuses it, because squashed commits are not ancestors of the base. A branch checked out in a linked worktree needs `git worktree remove <path>` from the main checkout first, since the switch and the delete both fail there.
- Never `git reset`, `git checkout --`, `git stash` or `git clean`.
- After a merge for `Fixes #N`, check the issue closed: `gh issue view N --json state,projectItems`. A merge into an `epic/*` branch does not auto-close, so close it with `gh issue close N --comment "Shipped in <PR url>"`. A card not yet in `Done` moves with `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" N --status Done`. A `refs #N` slice stays open.

## Template

```markdown
## Ship brief

**Change:** one line, plus the issue it closes (`Fixes #N`) or refers to (`refs #N`)
**Paths to stage:** every path, one per line
**Branch:** `<name>` from `<base>`; `git switch -c` when HEAD is not on it (uncommitted work carries over), or `none` to commit on the current branch
**Commit message:** Conventional Commits subject, body says why
**PR:** title and body (Summary, Test plan, Out of scope) against `<base>`, or `none`
**Merge:** `squash` / `rebase` / `none`
**Deploy:** the project's deploy command, or `none`
**After:** the branch to leave HEAD on, or `stay`
```

## Report

```markdown
## Shipped
- Commit: <sha> <subject>
- PR: <url> | none
- Merge: <state> | none
- Deploy: <state> | not approved: <command> | none
- #N closed, board Done | #N open: <why, for example refs slice or no board>

## Stopped at
<step, exact command, the failing output's decisive line>   (omit when nothing stopped)
```
