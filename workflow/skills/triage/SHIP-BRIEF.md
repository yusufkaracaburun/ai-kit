# Ship brief

One change gets one ship brief. A single general-purpose subagent (Task tool) runs commit, PR, merge and deploy, in that order, and stops at the first red check or at a deploy the user has not approved. The lead writes the brief and reads the report; it never runs these steps itself. One spawn for the whole chain, because a spawn per step mostly pays start-up cost.

Skills that hand off to it: `to-prd` (Idea mode), `autonomous`, `harvest`, `diagnose`.

## Rules for the subagent

- Precondition: the staged tree carries a `/ai:review` APPROVE; stage nothing beyond the reviewed paths.
- Run the steps in order; skip a step only when its field says `none`.
- Stage by path and read `git diff --staged` before the commit. Never `git commit -a`, `--no-verify` or a force push.
- A failed hook, a denied commit or push, or a red CI check is a stop: report the command and its output, change nothing else.
- Merge only when the field says so and the project's merge policy allows it. Deploy only when the user approved this deploy in this conversation; otherwise stop before it and print the deploy command (see the `deployment-on-demand` rule).
- After a squash merge, delete the local branch only once `gh pr view <n> --json state` says `MERGED`: switch to the base, then `git branch -D <branch>`. `-d` refuses it, because squashed commits are not ancestors of the base. Before `-D`, `git rev-parse <branch>` must equal `gh pr view <n> --json headRefOid -q .headRefOid`; if not, stop and report the local commits the PR lacks. A branch checked out in a linked worktree needs `git worktree remove <path>` from the main checkout first, since the switch and the delete both fail there; if it refuses a dirty worktree, stop and report, never `--force`.
- Never `git reset`, `git checkout --`, `git stash` or `git clean`.
- **Card boxes, before the push or merge that closes a card** (also an epic, with its Done when and Definition of Done). The boxes are those under Acceptance criteria, Done when and Definition of Done; a card without any skips this rule and the next two.
  1. Proof per box: the PROVEN entries of the verifier the brief quotes (autonomous runs), or evidence you produced or were given yourself (lead runs): a commit, test output, `file:line`, a measurement. No evidence for that one box: it stays open. A box ticked before you came counts as open too until you have evidence for it, although the script does not print it.
  2. After the commit, post one evidence comment on the card: the SHA, and per box its evidence or why it stays open. A quoted review or verifier report goes in there. Keep the comment's URL.
  3. Write the proven boxes' exact text, one per line, to a file and run `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-tick-dod.sh" N <file>`. It ticks those boxes only and prints each one that stays open. A refusal is a stop before the push; never edit the body another way.
- **A box stays open: no closing keyword.** Write `Refs #N` in the commit message, PR title and PR body, and name the open boxes in the report. Decide this before the commit; when the script prints an open box you did not expect, stop before the push.
- **Post-merge boxes** (proof exists only after the push or merge, such as sub-issues closed or the commit on main) stay open until then. After the push or merge that lands it on the base, prove each by its command, tick it with the same script, add the merge SHA and its evidence to the same comment (`gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -F body=@<file>`), and only when no box is open any more: `gh issue close N`. When this brief lands nothing on the base, the PR body lists those boxes with their commands.
- After a merge for `Fixes #N`, check the issue closed: `gh issue view N --json state,projectItems`. A merge into an `epic/*` branch does not auto-close, so close it with `gh issue close N --comment "Shipped in <PR url>"`. A closed card not yet in `Done` moves with `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/bin/ai-kit-issue-meta.sh" N --status Done`. A `refs #N` story stays open.

## Template

```markdown
## Ship brief

**Change:** one line, plus the issue it closes (`Fixes #N`) or refers to (`refs #N`)
**Boxes:** the verifier's `## Boxes` entries and the review verdict, or `own evidence`, or `none` (no card, or no boxes on it)
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
- #N closed, board Done | #N open: <why, for example open boxes, refs story or no board>
- Boxes: <n> ticked, evidence <comment url> | open: <box and reason, one per line> | none

## Stopped at
<step, exact command, the failing output's decisive line>   (omit when nothing stopped)
```
