#!/usr/bin/env bash
# Bump VERSION, prepend a CHANGELOG entry, commit, tag. No push (deliberate —
# the maintainer chooses when to publish).
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"

usage() {
  cat <<USAGE
Usage: $0 <new-version> [--notes-file=<path>] [--no-tag] [--dry-run]

Examples:
  $0 1.2.1                              prompt for changelog entry inline
  $0 1.3.0 --notes-file=/tmp/notes.md   use prepared notes
  $0 1.3.0 --dry-run                    print what would happen, change nothing

Performs:
  1. Updates VERSION
  2. Prepends a Keep-a-Changelog entry to CHANGELOG.md
  3. Commits the two files with subject "chore(release): vX.Y.Z"
  4. Tags vX.Y.Z (unless --no-tag)

Does NOT push. Run 'git push origin master --tags' yourself once happy.
USAGE
  exit 1
}

if [ $# -lt 1 ]; then usage; fi

NEW_VERSION=""
NOTES_FILE=""
DO_TAG=true
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --no-tag) DO_TAG=false ;;
    --dry-run) DRY_RUN=true ;;
    --notes-file=*) NOTES_FILE="${arg#*=}" ;;
    -*) echo "Unknown flag: $arg" >&2; usage ;;
    *)
      if [ -n "$NEW_VERSION" ]; then echo "Unexpected arg: $arg" >&2; usage; fi
      NEW_VERSION="$arg"
      ;;
  esac
done

if ! printf '%s' "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$'; then
  echo "Invalid version: '$NEW_VERSION' — expected semver X.Y.Z (optional -prerelease)" >&2
  exit 2
fi

cd "$AIKIT"

if [ ! -d ".git" ]; then
  echo "Not a git repo: $AIKIT" >&2
  exit 2
fi

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"
if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  echo "VERSION is already $NEW_VERSION — nothing to bump" >&2
  exit 2
fi

if [ "$DRY_RUN" = false ]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree not clean — commit or stash first" >&2
    git status --short
    exit 2
  fi

  if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    echo "Tag v$NEW_VERSION already exists" >&2
    exit 2
  fi
fi

# Build the CHANGELOG entry.
TODAY="$(date -u +%Y-%m-%d)"
if [ -n "$NOTES_FILE" ]; then
  if [ ! -f "$NOTES_FILE" ]; then
    echo "Notes file not found: $NOTES_FILE" >&2
    exit 2
  fi
  NOTES_BODY="$(cat "$NOTES_FILE")"
else
  echo "Paste CHANGELOG entry body (omit the heading — script adds it). End with Ctrl-D:" >&2
  NOTES_BODY="$(cat)"
  if [ -z "$NOTES_BODY" ]; then
    echo "Empty changelog body — aborting" >&2
    exit 2
  fi
fi

NEW_ENTRY="## $NEW_VERSION — $TODAY

$NOTES_BODY
"

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] Would write VERSION = $NEW_VERSION"
  echo "[dry-run] Would prepend CHANGELOG entry:"
  printf '%s\n' "$NEW_ENTRY" | sed 's/^/  | /'
  echo "[dry-run] Would commit: 'chore(release): v$NEW_VERSION'"
  [ "$DO_TAG" = true ] && echo "[dry-run] Would tag: v$NEW_VERSION"
  exit 0
fi

printf '%s\n' "$NEW_VERSION" > VERSION

python3 - "$NEW_ENTRY" <<'PY'
import sys, pathlib
new_entry = sys.argv[1]
p = pathlib.Path("CHANGELOG.md")
src = p.read_text()
header_end = src.find("\n", src.find("# Changelog")) + 1
out = src[:header_end] + "\n" + new_entry + src[header_end:]
p.write_text(out)
PY

# Keep plugin manifest + marketplace catalog in lockstep with VERSION.
bash "$SCRIPT_BIN/sync-plugin-version.sh"

git add VERSION CHANGELOG.md workflow/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): v$NEW_VERSION"

if [ "$DO_TAG" = true ]; then
  git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
  echo ""
  echo "Tagged v$NEW_VERSION. Push when ready:"
  echo "  git push origin master --tags"
else
  echo ""
  echo "Released v$NEW_VERSION (no tag). Push when ready:"
  echo "  git push origin master"
fi
