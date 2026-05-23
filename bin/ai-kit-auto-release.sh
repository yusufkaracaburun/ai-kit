#!/usr/bin/env bash
# Pick a semver bump from Conventional Commits since the last tag and run
# release.sh --bump-marketplace. Skip when only chore/docs/test/refactor.
#
#   feat!: | fix!: | BREAKING CHANGE → major
#   feat:                            → minor
#   fix: | perf:                     → patch
#
# Pass --dry-run to print the chosen bump + notes without releasing.
set -euo pipefail

cd "$(dirname "$0")/.."

DRY=${1:-}
LAST="$(git tag --list 'v*' --sort=-v:refname | head -1)"
[ -z "$LAST" ] && { echo "No prior v* tag" >&2; exit 2; }

LOG="$(git log --format='%s%n%b' "$LAST..HEAD")"
[ -z "$LOG" ] && { echo "No commits since $LAST"; exit 0; }

if   echo "$LOG" | grep -qE '^(feat|fix)(\([^)]*\))?!:|BREAKING CHANGE'; then BUMP=major
elif echo "$LOG" | grep -qE '^feat(\([^)]*\))?:';                        then BUMP=minor
elif echo "$LOG" | grep -qE '^(fix|perf)(\([^)]*\))?:';                  then BUMP=patch
else echo "No feat/fix/perf since $LAST — skipping"; exit 0
fi

IFS=. read -r M m p <<<"${LAST#v}"
case $BUMP in major) ((M++)); m=0; p=0;; minor) ((m++)); p=0;; patch) ((p++));; esac
NEXT="$M.$m.$p"

NOTES="$(mktemp)"
git log --format='- %s' "$LAST..HEAD" > "$NOTES"

echo "$LAST → v$NEXT ($BUMP, $(wc -l <"$NOTES" | tr -d ' ') commits)"
[ "$DRY" = "--dry-run" ] && { cat "$NOTES"; exit 0; }

exec bin/release.sh "$NEXT" --notes-file="$NOTES" --bump-marketplace
