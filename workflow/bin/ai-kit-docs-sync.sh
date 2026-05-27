#!/usr/bin/env bash
# Run all ai-kit docs-sync checks against the current project.
#
# Sections:
#   1. dead-links   — markdown `[text](path)` link integrity (relative + repo-absolute paths)
#   2. repo-hygiene — empty dirs, broken symlinks, orphan .agents/skills/<name>/ dirs
#
# Reports content + structural drift. Framework health lives in ai-kit-hygiene.sh.
# Reports-only by default; per-finding fix suggestions surface behind an
# explicit y/N prompt when stdin is a TTY. Never auto-edits markdown files.
#
# Exit code = max of the section exit codes (0 clean, 1 warn).
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<USAGE
Usage: $0 [path] [--skip-dead-links] [--skip-repo-hygiene] [--no-prompt]

Runs ai-kit docs-sync checks against the given project path (default: cwd).
Exit code = max of the section exit codes (0 clean, 1 warn).

Flags:
  --skip-dead-links     Bypass the markdown dead-links section.
  --skip-repo-hygiene   Bypass the repo-hygiene section (empty dirs, broken symlinks, orphan skill dirs).
  --no-prompt           Never prompt for fix suggestions (auto-set when stdin is not a TTY).
USAGE
}

PROJECT_PATH=""
SKIP_DEAD_LINKS=0
SKIP_REPO_HYGIENE=0
NO_PROMPT=0

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --skip-dead-links)   SKIP_DEAD_LINKS=1 ;;
    --skip-repo-hygiene) SKIP_REPO_HYGIENE=1 ;;
    --no-prompt)         NO_PROMPT=1 ;;
    -*) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "docs-sync: project path does not exist: $PROJECT_PATH" >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Auto-disable prompt when stdin is not a TTY (CI, eval framework, pipes).
if [ ! -t 0 ]; then
  NO_PROMPT=1
fi

max_exit=0
record() {
  local code="$1"
  [ "$code" -gt "$max_exit" ] && max_exit="$code"
}

section() {
  printf '\n=== %s ===\n' "$1"
}

if [ "$SKIP_DEAD_LINKS" -eq 0 ]; then
  section "dead-links (markdown link integrity)"
  bash "$AIKIT/bin/ai-kit-docs-sync-dead-links.sh" "$PROJECT_PATH" \
    $([ "$NO_PROMPT" -eq 1 ] && echo "--no-prompt")
  record "$?"
fi

if [ "$SKIP_REPO_HYGIENE" -eq 0 ]; then
  section "repo-hygiene (empty dirs / broken symlinks / orphan skill dirs)"
  bash "$AIKIT/bin/ai-kit-docs-sync-repo-hygiene.sh" "$PROJECT_PATH" \
    $([ "$NO_PROMPT" -eq 1 ] && echo "--no-prompt")
  record "$?"
fi

section "summary"
case "$max_exit" in
  0) echo "docs-sync: all sections clean." ;;
  1) echo "docs-sync: findings reported (exit 1)." ;;
  *) echo "docs-sync: error (exit $max_exit)." ;;
esac

exit "$max_exit"
