#!/usr/bin/env bash
# Re-stamp the plugin manifest with the current ai-kit VERSION.
# Idempotent; safe to run on every release.
#
# VERSION is the single source of truth. One derived location must stay in
# sync:
#   1. workflow/.claude-plugin/plugin.json:version
#
# The marketplace catalog used to live in this repo too — it has been moved
# to the standalone https://github.com/yusufkaracaburun/marketplace repo
# (one catalog for all yusufkaracaburun plugins). After each ai-kit release
# tag, that repo's `.claude-plugin/marketplace.json` must also be updated;
# release.sh prints a reminder.
#
# Usage:
#   sync-plugin-version.sh           # stamp from VERSION
#   sync-plugin-version.sh --check   # verify equality, exit 1 on drift
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

VERSION_FILE="$AIKIT/VERSION"
PLUGIN_JSON="$AIKIT/workflow/.claude-plugin/plugin.json"

if [ ! -f "$VERSION_FILE" ]; then
  echo "VERSION file missing at $VERSION_FILE" >&2
  exit 2
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help)
    sed -n '1,16p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
esac

# Extract / set the top-level "version" field of a JSON file via python3.
extract_version() {
  local file="$1"
  python3 -c "
import json
print(json.load(open('$file'))['version'])
"
}

set_version() {
  local file="$1"
  local new_version="$2"
  python3 -c "
import json
d = json.load(open('$file'))
d['version'] = '$new_version'
with open('$file','w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
}

CURRENT_PLUGIN="$(extract_version "$PLUGIN_JSON")"

case "$MODE" in
  check)
    if [ "$VERSION" != "$CURRENT_PLUGIN" ]; then
      echo "DRIFT: VERSION=$VERSION but plugin.json:version=$CURRENT_PLUGIN" >&2
      exit 1
    fi
    echo "OK: VERSION/plugin.json both at $VERSION"
    exit 0
    ;;
  stamp)
    if [ "$VERSION" = "$CURRENT_PLUGIN" ]; then
      echo "Already at $VERSION (no changes)"
      exit 0
    fi
    set_version "$PLUGIN_JSON" "$VERSION"
    echo "Stamped $VERSION into:"
    echo "  $PLUGIN_JSON"
    ;;
esac
