#!/usr/bin/env bash
# Mirror standards/ → workflow/standards/ so the plugin install ships the
# canonical rules + external catalogs (plugins.json, mcp-servers.json,
# hooks-patterns.json, VETTING.md). Without this mirror, plugin-cache lookups
# from bin/ai-kit-audit-ecosystem.sh + bin/recommend-tools.sh fail and every
# host primitive is misclassified as ADOPT (false positive — issue #41 hotfix).
#
# Symmetric to bin/sync-plugin-bin.sh.
#
# Usage:
#   sync-plugin-standards.sh          # mirror standards/ → workflow/standards/
#   sync-plugin-standards.sh --check  # exit 1 if any file drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
SRC="$AIKIT/standards"
DST="$AIKIT/workflow/standards"

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
    echo "Drift: workflow/standards/ differs from standards/" >&2
    diff -rq "$SRC" "$DST" 2>&1 | head -20 >&2
    echo "" >&2
    echo "Run bin/sync-plugin-standards.sh to re-stamp." >&2
    exit 1
  fi
  exit 0
fi

mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"
echo "Synced: $DST (from $SRC)"
