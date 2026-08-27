#!/usr/bin/env bash
# Mirror orchestration/ → workflow/orchestration/ so the plugin install ships
# the Sandcastle scaffold templates.
#
# Without this mirror, bin/apply-sandcastle.sh resolves $AIKIT to workflow/
# when it runs from the plugin, looks for workflow/orchestration/sandcastle/,
# finds nothing, and leaves an EMPTY .sandcastle/ behind — /ai:setup branch 8
# reports success and scaffolds nothing. The four sibling mirrors existed;
# this directory was simply never added to the set.
#
# Symmetric to bin/sync-plugin-bin.sh, bin/sync-plugin-hooks.sh,
# bin/sync-plugin-standards.sh, bin/sync-plugin-context.sh.
#
# Usage:
#   sync-plugin-orchestration.sh          # mirror orchestration/ → workflow/orchestration/
#   sync-plugin-orchestration.sh --check  # exit 1 if any file drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
SRC="$AIKIT/orchestration"
DST="$AIKIT/workflow/orchestration"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,16p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

if [ ! -d "$SRC" ]; then
  echo "Source missing: $SRC" >&2
  exit 2
fi

if [ "$MODE" = "check" ]; then
  if [ ! -d "$DST" ] || ! diff -rq "$SRC" "$DST" >/dev/null 2>&1; then
    echo "Drift: workflow/orchestration/ differs from orchestration/" >&2
    diff -rq "$SRC" "$DST" 2>&1 | head -20 >&2
    echo "" >&2
    echo "Run bin/sync-plugin-orchestration.sh to re-stamp." >&2
    exit 1
  fi
  exit 0
fi

mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"
echo "Synced: $DST (from $SRC)"
