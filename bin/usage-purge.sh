#!/usr/bin/env bash
# Wipe the local ai-kit usage log.
# Usage: usage-purge.sh [--yes]
set -euo pipefail

AUTO_CONFIRM=false
if [ "${1:-}" = "--yes" ]; then
  AUTO_CONFIRM=true
fi

log_file="${XDG_STATE_HOME:-$HOME/.local/state}/ai-kit/usage.jsonl"

if [ ! -f "$log_file" ]; then
  echo "No usage log at $log_file"
  exit 0
fi

size_bytes="$(wc -c < "$log_file" | tr -d ' ')"
echo "Will delete: $log_file (${size_bytes} bytes)"

if [ "$AUTO_CONFIRM" != true ]; then
  printf "Delete? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled"; exit 0 ;;
  esac
fi

rm -f "$log_file"
echo "Deleted."
