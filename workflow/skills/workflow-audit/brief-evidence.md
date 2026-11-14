# Brief: evidence

Collect real-use evidence for the ai-kit workflow since `<since>`. Sources are memory files, `git log`, `gh` and kit docs only.

Repo paths come from the previous report's Per repo table (Path column); never decode memory dir names into paths. A repo's memory lives in `~/.claude/projects/<encoded path>/memory/`, where the encoded path is the repo path with `/` replaced by `-`.

## Part 1: kit

1. **Open issues by theme.** `gh issue list --repo yusufkaracaburun/ai-kit --state open --limit 200 --json number,title,labels,updatedAt`. Group by theme, count per theme, flag issues not updated since `<since>`.
2. **Roadmap drift.** Open issues missing from `docs/roadmap.md`, roadmap entries whose issue is closed, and the reconcile date at the top.
3. **Corrections and slipped bugs.** Kit memory `feedback_*.md` and `project/*.md` modified since `<since>`: each correction the user made and each defect found after a done claim.
4. **Open re-measurements.** Memory entries with a due date or "measure", "re-check", "trial" that have no closing result. Give the due date.
5. **Changelog churn.** `workflow/CHANGELOG.md` entries since `<since>`: surfaces changed in two or more releases (hooks, lead contract, model defaults, one skill).
6. **Score.** Last row of `docs/score.md` and its date.

## Part 2: per downstream repo

Repos: the names and paths the lead passes (taken from the previous report). A memory dir that changed since `<since>` but has no path in that table goes under "Unmapped memory dirs"; ask the lead for its path, do not guess it.

| Repo | Path | Marker version | Lifecycle | Commits since | Fix-ish commits | Ratio | Gate in effect | Skips logged | Owner-found defects |

- Marker version and lifecycle: `jq -r '.ai_kit_version, (.branches.lifecycle // "production")' .ai-kit-setup`.
- Fix-ish over commits since, on the default branch, subjects only, merges excluded: with `b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo master)`, `git log "$b" --no-merges --since=<since> --format=%s | grep -ciE '^(fix|revert)|hotfix|regress'` over `git log "$b" --no-merges --since=<since> --format=%s | wc -l`. State it is an upper bound.
- Gate in effect: yes when the marker version is 2.17.0 or later and `jq -r '.branches.review_gate_hook // "wired"' .ai-kit-setup` is `wired`; otherwise no.
- Skips logged: line count of `$(git rev-parse --git-dir)/ai-kit/gate-log` in the main checkout only. Only `--skip` approvals are logged, so give the count, never a share.
- Owner-found defects: feedback and project memos in that repo's memory dir since `<since>` where the user found a defect before the lead or a reviewer. Give the date and one line each. Count per week for the busiest repo (most commits since `<since>`).
- Lead-inline sessions: only if a kit or repo memo reports a fresh count; never estimate it.

## Return format

Part 1 as six short lists, Part 2 as the table plus one evidence line per defect.
