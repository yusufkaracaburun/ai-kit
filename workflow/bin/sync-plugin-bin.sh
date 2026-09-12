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
# shellcheck source=lib/sync-mirror.sh
source "$SCRIPT_BIN/lib/sync-mirror.sh"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,12p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

sync_mirror "$AIKIT/bin" "$AIKIT/workflow/bin" "$MODE" "bin/sync-plugin-bin.sh"
