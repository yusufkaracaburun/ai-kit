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
# shellcheck source=lib/sync-mirror.sh
source "$SCRIPT_BIN/lib/sync-mirror.sh"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,15p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

sync_mirror "$AIKIT/context" "$AIKIT/workflow/context" "$MODE" "bin/sync-plugin-context.sh"
