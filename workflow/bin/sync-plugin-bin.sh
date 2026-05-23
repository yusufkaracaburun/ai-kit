#!/usr/bin/env bash
# Mirror bin/ → workflow/bin/ so the plugin install ships every script
# its slash-commands need. Without this, plugin commands resolve
# ${CLAUDE_PLUGIN_ROOT}/bin/<script>.sh and the global clone becomes a
# hidden runtime dependency.
#
# Usage:
#   sync-plugin-bin.sh          # mirror bin/ → workflow/bin/
#   sync-plugin-bin.sh --check  # exit 1 if any file drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
SRC="$AIKIT/bin"
DST="$AIKIT/workflow/bin"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,12p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

if [ "$MODE" = "check" ]; then
  if [ ! -d "$DST" ] || ! diff -rq "$SRC" "$DST" >/dev/null 2>&1; then
    echo "Drift: workflow/bin/ differs from bin/" >&2
    diff -rq "$SRC" "$DST" 2>&1 | head -20 >&2
    echo "" >&2
    echo "Run bin/sync-plugin-bin.sh to re-stamp." >&2
    exit 1
  fi
  exit 0
fi

mkdir -p "$DST"
# Mirror: copy new/changed, delete extras. --delete-excluded covers --exclude'd files too.
rsync -a --delete "$SRC/" "$DST/"
echo "Synced: $DST (from $SRC)"
