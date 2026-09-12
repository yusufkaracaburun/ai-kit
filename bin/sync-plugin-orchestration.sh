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
# shellcheck source=lib/sync-mirror.sh
source "$SCRIPT_BIN/lib/sync-mirror.sh"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,16p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

sync_mirror "$AIKIT/orchestration" "$AIKIT/workflow/orchestration" "$MODE" "bin/sync-plugin-orchestration.sh"
