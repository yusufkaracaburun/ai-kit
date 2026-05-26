#!/usr/bin/env bash
# Mirror context/ → workflow/context/ so the plugin install ships the
# templates and prompt fixtures that bin/setup-gh-workflow.sh,
# bin/bootstrap-project.sh, bin/apply-docker.sh, and several skills resolve
# via $AI_KIT_ROOT/context/**. Without this mirror the cached plugin install
# hard-exits with "Templates missing: <root>/context/templates/github" and
# every context-template lookup becomes a hidden runtime dependency on a
# global ai-kit clone.
#
# Symmetric to bin/sync-plugin-bin.sh, bin/sync-plugin-hooks.sh,
# bin/sync-plugin-standards.sh.
#
# Usage:
#   sync-plugin-context.sh          # mirror context/ → workflow/context/
#   sync-plugin-context.sh --check  # exit 1 if any file drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
SRC="$AIKIT/context"
DST="$AIKIT/workflow/context"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,15p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

if [ ! -d "$SRC" ]; then
  echo "Source missing: $SRC" >&2
  exit 2
fi

if [ "$MODE" = "check" ]; then
  if [ ! -d "$DST" ] || ! diff -rq "$SRC" "$DST" >/dev/null 2>&1; then
    echo "Drift: workflow/context/ differs from context/" >&2
    diff -rq "$SRC" "$DST" 2>&1 | head -20 >&2
    echo "" >&2
    echo "Run bin/sync-plugin-context.sh to re-stamp." >&2
    exit 1
  fi
  exit 0
fi

mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"
echo "Synced: $DST (from $SRC)"
