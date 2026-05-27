#!/usr/bin/env bash
# Print the docs-sync + hygiene cross-cues for a project, if applicable.
#
# Usage:
#   ai-kit-docs-sync-nudge.sh [path] [--context=<checkpoint|ship|triage>]
#
# Output (each line conditional on applicability):
#   Before clear, consider:
#     /ai:hygiene — framework wiring + install health
#     /ai:docs-sync — universal content drift (dead links, repo-hygiene, finished-work cleanup)
#
# When neither nudge is applicable, prints nothing and exits 0. Callers
# (checkpoint / ship / triage skills) decide where in their output the
# nudge belongs.
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/applicability.sh
source "$SCRIPT_BIN/lib/applicability.sh"

PROJECT_PATH=""
CONTEXT="generic"
for arg in "$@"; do
  case "$arg" in
    --context=*) CONTEXT="${arg#--context=}" ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done
PROJECT_PATH="${PROJECT_PATH:-$PWD}"

HYGIENE_LINE=""
DOCS_LINE=""
if is_hygiene_applicable "$PROJECT_PATH"; then
  HYGIENE_LINE="  /ai:hygiene — framework wiring + install health"
fi
if is_docs_sync_applicable "$PROJECT_PATH"; then
  DOCS_LINE="  /ai:docs-sync — universal content drift (dead links, repo-hygiene, finished-work cleanup)"
fi

if [ -z "$HYGIENE_LINE" ] && [ -z "$DOCS_LINE" ]; then
  exit 0
fi

case "$CONTEXT" in
  checkpoint) echo "Before clear, consider:" ;;
  ship)       echo "Closing this release? Consider:" ;;
  triage)     echo "After closing issues, consider:" ;;
  *)          echo "Cross-cue:" ;;
esac
[ -n "$HYGIENE_LINE" ] && echo "$HYGIENE_LINE"
[ -n "$DOCS_LINE" ] && echo "$DOCS_LINE"
exit 0
