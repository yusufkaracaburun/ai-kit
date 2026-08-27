#!/usr/bin/env bash
# Bump VERSION, prepend a CHANGELOG entry, commit, tag. Optionally push the
# ai-kit release AND bump the downstream marketplace catalog so
# /plugin update picks it up (a single end-to-end publish).
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"

MARKETPLACE_REPO="git@github.com:yusufkaracaburun/marketplace.git"

usage() {
  cat <<USAGE
Usage: $0 <new-version> [--notes-file=<path>] [--no-tag] [--dry-run] [--bump-marketplace]

Examples:
  $0 1.2.1                              prompt for changelog entry inline
  $0 1.3.0 --notes-file=/tmp/notes.md   use prepared notes
  $0 1.3.0 --dry-run                    print what would happen, change nothing
  $0 1.3.0 --notes-file=/tmp/n.md --bump-marketplace
                                        full publish: tag, push ai-kit, then
                                        bump + push the marketplace catalog

Performs:
  1. Updates VERSION
  2. Prepends a Keep-a-Changelog entry to CHANGELOG.md
  3. Commits the two files with subject "chore(release): vX.Y.Z"
  4. Tags vX.Y.Z (unless --no-tag)

With --bump-marketplace it also:
  5. Pushes ai-kit master + tags to origin
  6. Clones $MARKETPLACE_REPO, jq-patches .claude-plugin/marketplace.json
     (plugins[0].version + plugins[0].source.ref → vX.Y.Z)
  7. Commits + pushes the marketplace bump

Without --bump-marketplace the script stops after step 4.
USAGE
  exit 1
}

if [ $# -lt 1 ]; then usage; fi

NEW_VERSION=""
NOTES_FILE=""
DO_TAG=true
DRY_RUN=false
BUMP_MARKETPLACE=false
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --no-tag) DO_TAG=false ;;
    --dry-run) DRY_RUN=true ;;
    --bump-marketplace) BUMP_MARKETPLACE=true ;;
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

if [ "$BUMP_MARKETPLACE" = true ] && [ "$DO_TAG" = false ]; then
  echo "--bump-marketplace requires a tag (cannot be combined with --no-tag)" >&2
  exit 2
fi

cd "$AIKIT"

# `.git` is a FILE in a linked worktree, not a directory — a -d test there
# reports "not a git repo" and blocks every git-aware path. (#145)
if ! git rev-parse --git-dir >/dev/null 2>&1; then
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
  if [ "$BUMP_MARKETPLACE" = true ]; then
    echo "[dry-run] Would push origin master --tags"
    echo "[dry-run] Would clone $MARKETPLACE_REPO, bump version + ref to v$NEW_VERSION, push"
  fi
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

# Keep plugin manifest in lockstep with VERSION.
bash "$SCRIPT_BIN/sync-plugin-version.sh"
# Keep plugin-bundled hook scripts byte-identical to bin/ source-of-truth.
bash "$SCRIPT_BIN/sync-plugin-hooks.sh"
# Keep plugin-bundled bin/ scripts byte-identical to bin/ source-of-truth.
bash "$SCRIPT_BIN/sync-plugin-bin.sh"
# Keep plugin-bundled standards (canonical rules + external catalogs) in sync.
bash "$SCRIPT_BIN/sync-plugin-standards.sh"
# Keep plugin-bundled context (templates + prompts) in sync — ai-kit issues #67/#68.
bash "$SCRIPT_BIN/sync-plugin-context.sh"
# Keep plugin-bundled orchestration (Sandcastle scaffold templates) in sync.
# Missing this mirror is why plugin-side apply-sandcastle.sh scaffolded nothing.
bash "$SCRIPT_BIN/sync-plugin-orchestration.sh"

git add VERSION CHANGELOG.md workflow/.claude-plugin/plugin.json \
  workflow/hooks/post-skill-log.sh workflow/hooks/log-skill.sh \
  workflow/bin workflow/standards workflow/context workflow/orchestration
git commit -m "chore(release): v$NEW_VERSION"

if [ "$DO_TAG" = true ]; then
  git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
  echo ""
  echo "Tagged v$NEW_VERSION."
else
  echo ""
  echo "Released v$NEW_VERSION (no tag)."
fi

if [ "$BUMP_MARKETPLACE" = false ]; then
  if [ "$DO_TAG" = true ]; then
    echo "Push when ready:"
    echo "  git push origin master --tags"
  else
    echo "Push when ready:"
    echo "  git push origin master"
  fi
  echo ""
  echo "Next: bump the marketplace catalog so /plugin update picks this up."
  echo "  Re-run with --bump-marketplace to do this automatically, or:"
  echo "  cd /path/to/yusufkaracaburun/marketplace"
  echo "  jq '.plugins[0].version = \"$NEW_VERSION\" | .plugins[0].source.ref = \"v$NEW_VERSION\"' \\"
  echo "    .claude-plugin/marketplace.json > .claude-plugin/marketplace.tmp.json \\"
  echo "    && mv .claude-plugin/marketplace.tmp.json .claude-plugin/marketplace.json"
  echo "  git commit -am 'chore: bump ai-kit to v$NEW_VERSION'"
  echo "  git push origin master"
  exit 0
fi

# --- Marketplace bump (--bump-marketplace) ---------------------------------
echo ""
echo "Pushing ai-kit master + tags…"
git push origin master --tags

MKT_TMP="$(mktemp -d -t ai-kit-marketplace.XXXXXX)"
trap 'rm -rf "$MKT_TMP"' EXIT

echo "Cloning $MARKETPLACE_REPO → $MKT_TMP …"
git clone --quiet "$MARKETPLACE_REPO" "$MKT_TMP"

MKT_JSON="$MKT_TMP/.claude-plugin/marketplace.json"
if [ ! -f "$MKT_JSON" ]; then
  echo "Marketplace manifest not found at $MKT_JSON — aborting" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for --bump-marketplace but not on PATH" >&2
  exit 2
fi

jq --arg v "$NEW_VERSION" --arg ref "v$NEW_VERSION" \
  '.plugins[0].version = $v | .plugins[0].source.ref = $ref' \
  "$MKT_JSON" > "$MKT_JSON.tmp"
mv "$MKT_JSON.tmp" "$MKT_JSON"

cd "$MKT_TMP"
if git diff --quiet; then
  echo "Marketplace already at v$NEW_VERSION — nothing to push"
else
  git add .claude-plugin/marketplace.json
  git commit -m "chore: bump ai-kit to v$NEW_VERSION"
  git push origin HEAD
  echo "Marketplace bumped + pushed."
fi
cd "$AIKIT"

# Postscript: surface the user-side steps the agent's auto-classifier blocks
# on. Plugin lifecycle commands (uninstall/install) write under ~/.claude/
# and trigger the self-modification refusal even when the intent is benign,
# so they have to be run by the user. Same goes for `/plugin marketplace
# update` if the client hasn't auto-refreshed. See docs/auto-classifier-
# boundaries.md for the full classifier policy + workarounds.
cat <<POSTSCRIPT

Released v$NEW_VERSION end-to-end (ai-kit + marketplace).

Next steps (user-runnable; agent is blocked by the auto-classifier on
plugin lifecycle + ~/.claude/** writes):

  1. Refresh the local marketplace clone so the new ref is visible:
       /plugin marketplace update yusufkaracaburun
  2. Reinstall the plugin to pick up v$NEW_VERSION:
       /plugin uninstall ai && /plugin install ai@yusufkaracaburun
     (or, when supported in your client: /plugin update ai@yusufkaracaburun)
  3. In downstream projects already on ai-kit, re-stamp the marker:
       /ai:upgrade

Why this isn't automated: see docs/auto-classifier-boundaries.md.
POSTSCRIPT
