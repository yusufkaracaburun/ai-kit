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
# shellcheck source=lib/sync-mirror.sh
source "$SCRIPT_BIN/lib/sync-mirror.sh"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,15p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

sync_mirror "$AIKIT/standards" "$AIKIT/workflow/standards" "$MODE" "bin/sync-plugin-standards.sh"
