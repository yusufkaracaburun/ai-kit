#!/usr/bin/env bash
# Reopens a closed epic (issue type Epic or Feature) that still has open
# sub-issues without the later label, and comments which ones.
# Env: REPO (owner/name), ISSUE (number), LATER_LABEL (default na-migratie).
# Exits 1 after a reopen so the workflow run shows red, 0 otherwise.
set -euo pipefail

later="${LATER_LABEL:-na-migratie}"
case "$(gh api "repos/$REPO/issues/$ISSUE" --jq '.type.name // ""')" in
  Epic|Feature) ;;
  *) exit 0 ;;
esac

open="$(gh api --paginate "repos/$REPO/issues/$ISSUE/sub_issues" |
  jq -r --arg later "$later" '.[] | select(.state == "open" and ([.labels[].name] | index($later) | not)) | "- #\(.number) \(.title)"')"
[ -n "$open" ] || exit 0

# GITHUB_TOKEN cannot read a Projects board, so the list carries no board Status.
# Comment before reopen: gh skips -c when the enforce job already reopened the issue.
gh issue comment "$ISSUE" -R "$REPO" -b "Epic heropend: deze sub-issues staan nog open zonder label \`$later\`:

$open

Sluit ze eerst, of geef ze het label \`$later\` als ze na de epic mogen. Board-Status staat er niet bij: de workflow-token kan het board niet lezen."
gh issue reopen "$ISSUE" -R "$REPO"
echo "epic #$ISSUE reopened: open sub-issues without $later" >&2
exit 1
